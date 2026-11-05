import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AiService } from '../ai/ai.service';
import { CharacterService } from '../character/character.service';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ChatService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly characters: CharacterService,
    private readonly ai: AiService,
  ) {}

  private mapMessage(m: {
    id: string;
    sessionId: string;
    sender: string;
    content: string;
    createdAt: Date;
  }) {
    return {
      id: m.id,
      sessionId: m.sessionId,
      sender: m.sender,
      content: m.content,
      createdAt: m.createdAt,
    };
  }

  private parsePersona(personaJson: string) {
    try {
      return JSON.parse(personaJson || '{}') as {
        systemPrompt?: string;
        greetings?: string[];
        style?: string;
      };
    } catch {
      return {};
    }
  }

  async getOrCreateSelfSession(userId: string) {
    const { character } = await this.characters.myCharacter(userId);
    if (!character) {
      throw new BadRequestException('请先创建你的 AI 角色');
    }

    let session = await this.prisma.chatSession.findFirst({
      where: {
        ownerUserId: userId,
        characterId: character.id,
        type: 'self',
        status: 'active',
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!session) {
      session = await this.prisma.chatSession.create({
        data: {
          type: 'self',
          ownerUserId: userId,
          characterId: character.id,
        },
      });

      const owned = await this.characters.getOwned(userId, character.id);
      const persona = this.parsePersona(owned.personaJson);
      const greetings = persona.greetings ?? [];
      const hello =
        greetings[Math.floor(Math.random() * Math.max(greetings.length, 1))] ||
        `你好，我是${character.name}，从今天起陪着你。`;

      await this.prisma.chatMessage.create({
        data: {
          sessionId: session.id,
          sender: 'ai',
          content: hello,
        },
      });
    }

    const messages = await this.prisma.chatMessage.findMany({
      where: { sessionId: session.id },
      orderBy: { createdAt: 'asc' },
      take: 100,
    });

    return {
      session: {
        id: session.id,
        type: session.type,
        characterId: session.characterId,
        character,
        aiMode: this.ai.hasDeepSeek() ? 'deepseek' : 'local',
      },
      messages: messages.map((m) => this.mapMessage(m)),
    };
  }

  async listMessages(userId: string, sessionId: string) {
    const session = await this.prisma.chatSession.findUnique({
      where: { id: sessionId },
    });
    if (!session) throw new NotFoundException('会话不存在');
    if (session.ownerUserId !== userId) {
      throw new ForbiddenException('无权查看该会话');
    }
    const messages = await this.prisma.chatMessage.findMany({
      where: { sessionId },
      orderBy: { createdAt: 'asc' },
      take: 120,
    });
    return { items: messages.map((m) => this.mapMessage(m)) };
  }

  async send(userId: string, sessionId: string, content: string) {
    const text = content.trim();
    if (!text) throw new BadRequestException('内容不能为空');

    const session = await this.prisma.chatSession.findUnique({
      where: { id: sessionId },
      include: { character: true },
    });
    if (!session) throw new NotFoundException('会话不存在');
    if (session.ownerUserId !== userId || session.type !== 'self') {
      throw new ForbiddenException('无权在该会话发言');
    }

    const userMsg = await this.prisma.chatMessage.create({
      data: { sessionId, sender: 'user', content: text },
    });

    const history = await this.prisma.chatMessage.findMany({
      where: { sessionId },
      orderBy: { createdAt: 'desc' },
      take: 16,
    });
    history.reverse();

    const persona = this.parsePersona(session.character.personaJson);
    const system =
      persona.systemPrompt ||
      `你是陪伴角色「${session.character.name}」，请用简短温柔的中文回复。`;

    const aiMessages = [
      { role: 'system' as const, content: system },
      ...history.map((m) => ({
        role: (m.sender === 'user' ? 'user' : 'assistant') as
          | 'user'
          | 'assistant',
        content: m.content,
      })),
    ];

    const replyText = await this.ai.chat(aiMessages);
    const aiMsg = await this.prisma.chatMessage.create({
      data: { sessionId, sender: 'ai', content: replyText },
    });

    await this.prisma.chatSession.update({
      where: { id: sessionId },
      data: { updatedAt: new Date() },
    });

    return {
      userMessage: this.mapMessage(userMsg),
      aiMessage: this.mapMessage(aiMsg),
      aiMode: this.ai.hasDeepSeek() ? 'deepseek' : 'local',
    };
  }
}
