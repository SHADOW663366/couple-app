import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';
import { PrismaService } from '../prisma/prisma.service';
import { CreateDiaryDto } from './dto/diary.dto';

export type UploadedDiaryFile = {
  originalname: string;
  mimetype: string;
  size: number;
  buffer: Buffer;
};

@Injectable()
export class DiaryService {
  constructor(private readonly prisma: PrismaService) {}

  private mediaKind(mime: string): 'image' | 'audio' | null {
    if (mime.startsWith('image/')) return 'image';
    if (mime.startsWith('audio/')) return 'audio';
    return null;
  }

  private async saveFiles(entryId: string, files: UploadedDiaryFile[]) {
    if (!files.length) return [];
    const created = [];
    for (const file of files) {
      const kind = this.mediaKind(file.mimetype);
      if (!kind) {
        throw new BadRequestException(`不支持的文件类型: ${file.mimetype}`);
      }
      if (file.size > 8 * 1024 * 1024) {
        throw new BadRequestException('单个文件不能超过 8MB');
      }
      const row = await this.prisma.diaryMedia.create({
        data: {
          entryId,
          kind,
          url: 'pending',
          mime: file.mimetype,
          size: file.size,
          data: new Uint8Array(file.buffer),
        },
      });
      const updated = await this.prisma.diaryMedia.update({
        where: { id: row.id },
        data: { url: `/diary/media/${row.id}` },
      });
      created.push(updated);
    }
    return created;
  }

  private mapEntry(entry: {
    id: string;
    authorId: string;
    pairId: string | null;
    visibility: string;
    title: string | null;
    text: string;
    createdAt: Date;
    updatedAt: Date;
    media: Array<{
      id: string;
      kind: string;
      url: string;
      mime: string | null;
      durationMs: number | null;
      size: number | null;
      createdAt: Date;
    }>;
    blocks: Array<{
      id: string;
      authorId: string;
      text: string;
      createdAt: Date;
    }>;
  }) {
    return {
      id: entry.id,
      authorId: entry.authorId,
      pairId: entry.pairId,
      visibility: entry.visibility,
      title: entry.title,
      text: entry.text,
      media: entry.media.map((m) => ({
        id: m.id,
        kind: m.kind,
        url: m.url.startsWith('/diary/media/')
          ? m.url
          : `/diary/media/${m.id}`,
        mime: m.mime,
        durationMs: m.durationMs,
        size: m.size,
        createdAt: m.createdAt,
      })),
      blocks: entry.blocks.map((b) => ({
        id: b.id,
        authorId: b.authorId,
        text: b.text,
        createdAt: b.createdAt,
      })),
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    };
  }

  private include = {
    media: { orderBy: { createdAt: 'asc' as const } },
    blocks: { orderBy: { createdAt: 'asc' as const } },
  };

  async list(userId: string) {
    const me = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!me) throw new NotFoundException('用户不存在');

    const or: Array<Record<string, unknown>> = [
      { authorId: userId, visibility: { in: ['private', 'shared'] } },
    ];
    if (me.pairId) {
      or.push(
        { pairId: me.pairId, visibility: 'shared', authorId: { not: userId } },
        { pairId: me.pairId, visibility: 'joint' },
      );
    }

    const rows = await this.prisma.diaryEntry.findMany({
      where: { OR: or },
      include: this.include,
      orderBy: { updatedAt: 'desc' },
      take: 80,
    });
    return { items: rows.map((e) => this.mapEntry(e)) };
  }

  async getOne(userId: string, id: string) {
    const entry = await this.prisma.diaryEntry.findUnique({
      where: { id },
      include: this.include,
    });
    if (!entry) throw new NotFoundException('日记不存在');
    await this.assertCanRead(userId, entry);
    return this.mapEntry(entry);
  }

  private async assertCanRead(
    userId: string,
    entry: { authorId: string; pairId: string | null; visibility: string },
  ) {
    if (entry.authorId === userId) return;
    if (entry.visibility === 'private') {
      throw new ForbiddenException('无权查看这篇日记');
    }
    const me = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!me?.pairId || me.pairId !== entry.pairId) {
      throw new ForbiddenException('无权查看这篇日记');
    }
  }

  async getMediaFile(userId: string, mediaId: string) {
    const media = await this.prisma.diaryMedia.findUnique({
      where: { id: mediaId },
      include: { entry: true },
    });
    if (!media) throw new NotFoundException('附件不存在');
    await this.assertCanRead(userId, media.entry);

    if (media.data && media.data.length > 0) {
      return {
        data: Buffer.from(media.data),
        mime: media.mime || 'application/octet-stream',
      };
    }

    // 兼容旧版落盘文件
    if (media.url.startsWith('/uploads/')) {
      const filePath = path.join(process.cwd(), media.url.replace(/^\//, ''));
      if (fs.existsSync(filePath)) {
        return {
          data: fs.readFileSync(filePath),
          mime: media.mime || 'application/octet-stream',
        };
      }
    }

    throw new NotFoundException('附件数据不存在（可能已被清理）');
  }

  async create(userId: string, dto: CreateDiaryDto, files: UploadedDiaryFile[] = []) {
    const me = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!me) throw new NotFoundException('用户不存在');

    if ((dto.visibility === 'shared' || dto.visibility === 'joint') && !me.pairId) {
      throw new BadRequestException('分享或共同日记需要先绑定伴侣');
    }

    const text = (dto.text ?? '').trim();

    const entry = await this.prisma.diaryEntry.create({
      data: {
        authorId: userId,
        pairId: me.pairId,
        visibility: dto.visibility,
        title: dto.title?.trim() || null,
        text,
      },
    });

    if (files.length) {
      await this.saveFiles(entry.id, files);
    }

    if (dto.visibility === 'joint' && text) {
      await this.prisma.diaryBlock.create({
        data: {
          entryId: entry.id,
          authorId: userId,
          text,
        },
      });
    }

    return this.getOne(userId, entry.id);
  }

  async share(userId: string, id: string) {
    const entry = await this.prisma.diaryEntry.findUnique({ where: { id } });
    if (!entry) throw new NotFoundException('日记不存在');
    if (entry.authorId !== userId) {
      throw new ForbiddenException('只能分享自己的日记');
    }
    if (entry.visibility === 'joint') {
      throw new BadRequestException('共同日记无需再分享');
    }
    const me = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!me?.pairId) {
      throw new BadRequestException('绑定后才能分享给对方');
    }
    const updated = await this.prisma.diaryEntry.update({
      where: { id },
      data: { visibility: 'shared', pairId: me.pairId },
      include: this.include,
    });
    return this.mapEntry(updated);
  }

  async append(userId: string, id: string, text: string) {
    const entry = await this.prisma.diaryEntry.findUnique({ where: { id } });
    if (!entry) throw new NotFoundException('日记不存在');
    if (entry.visibility !== 'joint') {
      throw new BadRequestException('只有共同日记可以追加');
    }
    await this.assertCanRead(userId, entry);
    const trimmed = text.trim();
    if (!trimmed) throw new BadRequestException('内容不能为空');

    await this.prisma.diaryBlock.create({
      data: { entryId: id, authorId: userId, text: trimmed },
    });
    await this.prisma.diaryEntry.update({
      where: { id },
      data: { updatedAt: new Date() },
    });
    return this.getOne(userId, id);
  }

  async addMedia(userId: string, id: string, files: UploadedDiaryFile[]) {
    const entry = await this.prisma.diaryEntry.findUnique({ where: { id } });
    if (!entry) throw new NotFoundException('日记不存在');
    if (entry.visibility === 'joint') {
      await this.assertCanRead(userId, entry);
    } else if (entry.authorId !== userId) {
      throw new ForbiddenException('只能给自己的日记加附件');
    }
    if (!files.length) throw new BadRequestException('请选择文件');
    await this.saveFiles(id, files);
    await this.prisma.diaryEntry.update({
      where: { id },
      data: { updatedAt: new Date() },
    });
    return this.getOne(userId, id);
  }
}
