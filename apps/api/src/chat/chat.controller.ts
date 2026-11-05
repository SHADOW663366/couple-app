import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { ChatService } from './chat.service';
import { SendChatMessageDto } from './dto/chat.dto';

@Controller('chat')
@UseGuards(JwtAuthGuard)
export class ChatController {
  constructor(private readonly chat: ChatService) {}

  @Get('sessions/self')
  self(@CurrentUser() user: AuthUser) {
    return this.chat.getOrCreateSelfSession(user.id);
  }

  @Get('sessions/:id/messages')
  messages(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.chat.listMessages(user.id, id);
  }

  @Post('sessions/:id/messages')
  send(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: SendChatMessageDto,
  ) {
    return this.chat.send(user.id, id, dto.content);
  }
}
