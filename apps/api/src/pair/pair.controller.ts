import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { AcceptInviteDto } from './dto/pair.dto';
import { PairService } from './pair.service';

@Controller('pair')
@UseGuards(JwtAuthGuard)
export class PairController {
  constructor(private readonly pair: PairService) {}

  @Get('status')
  status(@CurrentUser() user: AuthUser) {
    return this.pair.status(user.id);
  }

  @Post('invite')
  createInvite(@CurrentUser() user: AuthUser) {
    return this.pair.createInvite(user.id);
  }

  @Post('accept')
  accept(@CurrentUser() user: AuthUser, @Body() dto: AcceptInviteDto) {
    return this.pair.acceptInvite(user.id, dto.code);
  }

  @Post('unbind')
  unbind(@CurrentUser() user: AuthUser) {
    return this.pair.unbind(user.id);
  }
}
