import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { AnswerTruthDto, CreateTruthSessionDto } from './dto/truth.dto';
import { TruthService } from './truth.service';

@Controller('truth')
@UseGuards(JwtAuthGuard)
export class TruthController {
  constructor(private readonly truth: TruthService) {}

  @Post('sessions')
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateTruthSessionDto) {
    return this.truth.create(user.id, dto);
  }

  @Get('sessions/active')
  active(@CurrentUser() user: AuthUser) {
    return this.truth.getActive(user.id);
  }

  @Get('sessions/:id')
  one(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.truth.getOne(user.id, id);
  }

  @Post('sessions/:id/draw')
  draw(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.truth.draw(user.id, id);
  }

  @Post('sessions/:id/answer')
  answer(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AnswerTruthDto,
  ) {
    return this.truth.answer(user.id, id, dto.answer);
  }

  @Post('sessions/:id/end')
  end(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.truth.end(user.id, id);
  }

  @Get('memories')
  memories(@CurrentUser() user: AuthUser, @Query('limit') limit?: string) {
    return this.truth.memories(user.id, limit ? Number(limit) : 30);
  }
}
