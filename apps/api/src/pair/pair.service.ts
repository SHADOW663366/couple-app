import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class PairService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  async createInvite(userId: string) {
    const me = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!me) {
      throw new NotFoundException('用户不存在');
    }
    if (me.pairId) {
      throw new ConflictException('已绑定情侣，无法再发邀请码');
    }

    const ttl =
      Number(this.config.get('INVITE_CODE_TTL_SECONDS')) || 1800;
    const code = this.randomCode(6);
    const expiresAt = new Date(Date.now() + ttl * 1000);

    await this.prisma.inviteCode.create({
      data: {
        code,
        creatorId: userId,
        expiresAt,
      },
    });

    return {
      code,
      expiresAt,
      qrPayload: `couple://pair?code=${code}`,
    };
  }

  async acceptInvite(userId: string, code: string) {
    const me = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!me) {
      throw new NotFoundException('用户不存在');
    }
    if (me.pairId) {
      throw new ConflictException('你已绑定情侣');
    }

    const invite = await this.prisma.inviteCode.findUnique({
      where: { code: code.toUpperCase() },
    });
    if (!invite || invite.usedAt || invite.expiresAt < new Date()) {
      throw new BadRequestException('邀请码无效或已过期');
    }
    if (invite.creatorId === userId) {
      throw new BadRequestException('不能绑定自己的邀请码');
    }

    const creator = await this.prisma.user.findUnique({
      where: { id: invite.creatorId },
    });
    if (!creator || creator.pairId) {
      throw new BadRequestException('邀请方状态不可绑定');
    }

    const result = await this.prisma.$transaction(async (tx) => {
      const pair = await tx.pair.create({
        data: { status: 'active' },
      });

      await tx.user.update({
        where: { id: creator.id },
        data: { pairId: pair.id },
      });
      await tx.user.update({
        where: { id: userId },
        data: { pairId: pair.id },
      });
      await tx.inviteCode.update({
        where: { id: invite.id },
        data: { usedAt: new Date() },
      });

      return pair;
    });

    return {
      pairId: result.id,
      boundAt: result.boundAt,
      message: '绑定成功',
    };
  }

  async status(userId: string) {
    const me = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        pair: {
          include: {
            users: {
              select: { id: true, nickname: true, email: true },
            },
          },
        },
      },
    });
    if (!me) {
      throw new NotFoundException('用户不存在');
    }

    if (!me.pair || me.pair.status !== 'active') {
      return { bound: false, pairId: null, partner: null };
    }

    const partner = me.pair.users.find((u) => u.id !== userId) ?? null;
    return {
      bound: true,
      pairId: me.pair.id,
      boundAt: me.pair.boundAt,
      partner,
    };
  }

  async unbind(userId: string) {
    const me = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!me?.pairId) {
      throw new BadRequestException('当前未绑定');
    }

    const pairId = me.pairId;
    await this.prisma.$transaction(async (tx) => {
      await tx.user.updateMany({
        where: { pairId },
        data: { pairId: null },
      });
      await tx.pair.update({
        where: { id: pairId },
        data: { status: 'dissolved' },
      });
    });

    return { ok: true, message: '已解除绑定' };
  }

  private randomCode(length: number) {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let out = '';
    for (let i = 0; i < length; i++) {
      out += alphabet[Math.floor(Math.random() * alphabet.length)];
    }
    return out;
  }
}
