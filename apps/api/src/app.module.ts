import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AiModule } from './ai/ai.module';
import { AuthModule } from './auth/auth.module';
import { CharacterModule } from './character/character.module';
import { ChatModule } from './chat/chat.module';
import { DiaryModule } from './diary/diary.module';
import { HealthController } from './health.controller';
import { PairModule } from './pair/pair.module';
import { PrismaModule } from './prisma/prisma.module';
import { TruthModule } from './truth/truth.module';
import { UserModule } from './user/user.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    AuthModule,
    UserModule,
    PairModule,
    TruthModule,
    DiaryModule,
    CharacterModule,
    AiModule,
    ChatModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}


