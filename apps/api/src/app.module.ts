import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from './auth/auth.module';
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
  ],
  controllers: [HealthController],
})
export class AppModule {}
