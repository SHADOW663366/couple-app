import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateTruthSessionDto } from './dto/truth.dto';
import { pickPrompt } from './truth.prompts';

@Injectable()
export class TruthService {
  constructor(private readonly prisma: PrismaService) {}

  async create(userId: string, dto: CreateTruthSessionDto) {
    const me = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!me) throw new NotFoundException('用户不存在');

    if (dto.mode === 'duo') {
      if (!me.pairId) {
        throw new BadRequestException('未绑定情侣，只能玩单人模式');
      }
      const pair = await this.prisma.pair.findUnique({
        where: { id: me.pairId },
        include: { users: { select: { id: true } } },
      });
      if (!pair || pair.status !== 'active' || pair.users.length < 2) {
        throw new BadRequestException('情侣关系无效');
      }
    }

    // 结束自己 / 情侣进行中的会话，避免多开
    await this.prisma.truthSession.updateMany({
      where: {
        status: 'active',
        OR: [
          { creatorId: userId },
          ...(me.pairId ? [{ pairId: me.pairId }] : []),
        ],
      },
      data: { status: 'ended' },
    });

    const level = dto.level ?? 1;
    const session = await this.prisma.truthSession.create({
      data: {
        mode: dto.mode,
        pairId: dto.mode === 'duo' ? me.pairId : null,
        creatorId: userId,
        currentTurnUserId: userId,
        status: 'active',
        currentLevel: level,
      },
    });

    return this.draw(userId, session.id);
  }

  async getActive(userId: string) {
    const me = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!me) throw new NotFoundException('用户不存在');

    const session = await this.prisma.truthSession.findFirst({
      where: {
        status: 'active',
        OR: [
          { creatorId: userId },
          { currentTurnUserId: userId },
          ...(me.pairId ? [{ pairId: me.pairId }] : []),
        ],
      },
      orderBy: { updatedAt: 'desc' },
      include: {
        rounds: { orderBy: { createdAt: 'desc' }, take: 5 },
      },
    });

    if (!session) return { session: null };
    return { session: await this.decorate(session, userId) };
  }

  async getOne(userId: string, sessionId: string) {
    const session = await this.prisma.truthSession.findUnique({
      where: { id: sessionId },
      include: { rounds: { orderBy: { createdAt: 'asc' } } },
    });
    if (!session) throw new NotFoundException('会话不存在');
    await this.assertParticipant(userId, session);
    return this.decorate(session, userId);
  }

  async draw(userId: string, sessionId: string) {
    const session = await this.prisma.truthSession.findUnique({
      where: { id: sessionId },
      include: { rounds: true },
    });
    if (!session || session.status !== 'active') {
      throw new BadRequestException('会话不可用');
    }
    await this.assertParticipant(userId, session);
    if (session.currentTurnUserId !== userId) {
      throw new ForbiddenException('还没轮到你抽题');
    }
    if (session.currentPrompt) {
      throw new BadRequestException('当前已有题目，请先回答');
    }

    const used = session.rounds.map((r) => r.prompt);
    const prompt = pickPrompt(session.currentLevel, used);
    const updated = await this.prisma.truthSession.update({
      where: { id: sessionId },
      data: { currentPrompt: prompt.text },
      include: { rounds: { orderBy: { createdAt: 'desc' }, take: 5 } },
    });
    return this.decorate(updated, userId);
  }

  async answer(userId: string, sessionId: string, answer: string) {
    const session = await this.prisma.truthSession.findUnique({
      where: { id: sessionId },
      include: {
        rounds: true,
      },
    });
    if (!session || session.status !== 'active') {
      throw new BadRequestException('会话不可用');
    }
    await this.assertParticipant(userId, session);
    if (session.currentTurnUserId !== userId) {
      throw new ForbiddenException('还没轮到你回答');
    }
    if (!session.currentPrompt) {
      throw new BadRequestException('请先抽题');
    }

    const text = answer.trim();
    if (!text) throw new BadRequestException('回答不能为空');

    let nextTurn = userId;
    if (session.mode === 'duo' && session.pairId) {
      const partners = await this.prisma.user.findMany({
        where: { pairId: session.pairId },
        select: { id: true },
      });
      const other = partners.find((p) => p.id !== userId);
      if (other) nextTurn = other.id;
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.truthRound.create({
        data: {
          sessionId,
          prompt: session.currentPrompt!,
          level: session.currentLevel,
          answererId: userId,
          answer: text,
        },
      });
      await tx.truthSession.update({
        where: { id: sessionId },
        data: {
          currentPrompt: null,
          currentTurnUserId: nextTurn,
        },
      });
    });

    const updated = await this.prisma.truthSession.findUnique({
      where: { id: sessionId },
      include: { rounds: { orderBy: { createdAt: 'desc' }, take: 5 } },
    });
    return this.decorate(updated!, userId);
  }

  async end(userId: string, sessionId: string) {
    const session = await this.prisma.truthSession.findUnique({
      where: { id: sessionId },
    });
    if (!session) throw new NotFoundException('会话不存在');
    await this.assertParticipant(userId, session);
    const updated = await this.prisma.truthSession.update({
      where: { id: sessionId },
      data: { status: 'ended', currentPrompt: null },
      include: { rounds: { orderBy: { createdAt: 'desc' }, take: 10 } },
    });
    return this.decorate(updated, userId);
  }

  async memories(userId: string, limit = 30) {
    const me = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!me) throw new NotFoundException('用户不存在');

    const sessions = await this.prisma.truthSession.findMany({
      where: {
        OR: [
          { creatorId: userId },
          ...(me.pairId ? [{ pairId: me.pairId }] : []),
        ],
      },
      select: { id: true },
    });
    const ids = sessions.map((s) => s.id);
    if (ids.length === 0) return { items: [] };

    const rounds = await this.prisma.truthRound.findMany({
      where: { sessionId: { in: ids } },
      orderBy: { createdAt: 'desc' },
      take: Math.min(limit, 50),
    });

    const userIds = [...new Set(rounds.map((r) => r.answererId))];
    const users = await this.prisma.user.findMany({
      where: { id: { in: userIds } },
      select: { id: true, nickname: true },
    });
    const map = Object.fromEntries(users.map((u) => [u.id, u.nickname]));

    return {
      items: rounds.map((r) => ({
        id: r.id,
        prompt: r.prompt,
        level: r.level,
        answer: r.answer,
        answererId: r.answererId,
        answererNickname: map[r.answererId] ?? '未知',
        createdAt: r.createdAt,
      })),
    };
  }

  private async assertParticipant(
    userId: string,
    session: { creatorId: string; pairId: string | null; mode: string },
  ) {
    if (session.creatorId === userId) return;
    if (session.mode === 'duo' && session.pairId) {
      const me = await this.prisma.user.findUnique({ where: { id: userId } });
      if (me?.pairId === session.pairId) return;
    }
    throw new ForbiddenException('无权访问该会话');
  }

  private async decorate(
    session: {
      id: string;
      mode: string;
      pairId: string | null;
      creatorId: string;
      currentTurnUserId: string;
      status: string;
      currentPrompt: string | null;
      currentLevel: number;
      createdAt: Date;
      updatedAt: Date;
      rounds?: Array<{
        id: string;
        prompt: string;
        level: number;
        answererId: string;
        answer: string;
        createdAt: Date;
      }>;
    },
    userId: string,
  ) {
    const turnUser = await this.prisma.user.findUnique({
      where: { id: session.currentTurnUserId },
      select: { id: true, nickname: true },
    });
    return {
      id: session.id,
      mode: session.mode,
      pairId: session.pairId,
      status: session.status,
      currentLevel: session.currentLevel,
      currentPrompt: session.currentPrompt,
      currentTurnUserId: session.currentTurnUserId,
      currentTurnNickname: turnUser?.nickname ?? null,
      myTurn: session.currentTurnUserId === userId,
      waitingDraw: session.currentTurnUserId === userId && !session.currentPrompt,
      waitingAnswer:
        session.currentTurnUserId === userId && Boolean(session.currentPrompt),
      rounds: session.rounds ?? [],
      createdAt: session.createdAt,
      updatedAt: session.updatedAt,
    };
  }
}
