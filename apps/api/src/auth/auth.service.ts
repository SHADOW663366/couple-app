import {
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../prisma/prisma.service';
import { LoginDto, RegisterDto } from './dto/auth.dto';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
  ) {}

  async register(dto: RegisterDto) {
    const exists = await this.prisma.user.findUnique({
      where: { email: dto.email.toLowerCase() },
    });
    if (exists) {
      throw new ConflictException('该邮箱已注册');
    }

    const passwordHash = await bcrypt.hash(dto.password, 10);
    const user = await this.prisma.user.create({
      data: {
        email: dto.email.toLowerCase(),
        passwordHash,
        nickname: dto.nickname,
      },
    });

    return this.tokenResponse(user.id, user.email, user.nickname, user.pairId);
  }

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email.toLowerCase() },
    });
    if (!user) {
      throw new UnauthorizedException('邮箱或密码错误');
    }

    const ok = await bcrypt.compare(dto.password, user.passwordHash);
    if (!ok) {
      throw new UnauthorizedException('邮箱或密码错误');
    }

    return this.tokenResponse(user.id, user.email, user.nickname, user.pairId);
  }

  private tokenResponse(
    userId: string,
    email: string,
    nickname: string,
    pairId: string | null,
  ) {
    const accessToken = this.jwt.sign({
      sub: userId,
      email,
    });
    return {
      accessToken,
      user: {
        id: userId,
        email,
        nickname,
        pairId,
        bound: Boolean(pairId),
      },
    };
  }
}
