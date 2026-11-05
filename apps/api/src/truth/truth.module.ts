import { Module } from '@nestjs/common';
import { TruthController } from './truth.controller';
import { TruthService } from './truth.service';

@Module({
  controllers: [TruthController],
  providers: [TruthService],
  exports: [TruthService],
})
export class TruthModule {}
