import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class UserService {
  constructor(private readonly prisma: PrismaService) {}

  async me(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        pair: {
          include: {
            users: {
              select: {
                id: true,
                nickname: true,
                email: true,
                avatarUrl: true,
              },
            },
          },
        },
      },
    });
    if (!user) {
      throw new NotFoundException('用户不存在');
    }

    const partner =
      user.pair?.users.find((u) => u.id !== user.id) ?? null;

    return {
      id: user.id,
      email: user.email,
      nickname: user.nickname,
      avatarUrl: user.avatarUrl,
      pairId: user.pairId,
      bound: Boolean(user.pairId && user.pair?.status === 'active'),
      partner,
      createdAt: user.createdAt,
    };
  }
}
