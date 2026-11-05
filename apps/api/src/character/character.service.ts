import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CHARACTER_PRESETS, findPreset } from './character.presets';
import { CreateCharacterDto, UpdateCharacterDto } from './dto/character.dto';

@Injectable()
export class CharacterService {
  constructor(private readonly prisma: PrismaService) {}

  presets() {
    return {
      items: CHARACTER_PRESETS.map((p) => ({
        artKey: p.artKey,
        name: p.name,
        tags: p.tags,
        style: p.style,
      })),
    };
  }

  private map(c: {
    id: string;
    ownerUserId: string;
    name: string;
    personaJson: string;
    artKey: string | null;
    createdAt: Date;
    updatedAt: Date;
  }) {
    let persona: Record<string, unknown> = {};
    try {
      persona = JSON.parse(c.personaJson || '{}') as Record<string, unknown>;
    } catch {
      persona = {};
    }
    return {
      id: c.id,
      ownerUserId: c.ownerUserId,
      name: c.name,
      artKey: c.artKey,
      tags: (persona.tags as string[]) ?? [],
      style: (persona.style as string) ?? '',
      createdAt: c.createdAt,
      updatedAt: c.updatedAt,
    };
  }

  async myCharacter(userId: string) {
    const c = await this.prisma.character.findFirst({
      where: { ownerUserId: userId },
      orderBy: { createdAt: 'asc' },
    });
    return { character: c ? this.map(c) : null };
  }

  async create(userId: string, dto: CreateCharacterDto) {
    const existing = await this.prisma.character.findFirst({
      where: { ownerUserId: userId },
    });
    if (existing) {
      throw new BadRequestException('你已有角色，请先使用现有角色聊天');
    }
    const preset = findPreset(dto.artKey);
    if (!preset) throw new BadRequestException('未知角色模板');

    const name = (dto.name?.trim() || preset.name).slice(0, 24);
    const personaJson = JSON.stringify({
      artKey: preset.artKey,
      tags: preset.tags,
      style: preset.style,
      systemPrompt: preset.systemPrompt,
      greetings: preset.greetings,
    });

    const c = await this.prisma.character.create({
      data: {
        ownerUserId: userId,
        name,
        artKey: preset.artKey,
        personaJson,
      },
    });
    return this.map(c);
  }

  async update(userId: string, id: string, dto: UpdateCharacterDto) {
    const c = await this.prisma.character.findUnique({ where: { id } });
    if (!c || c.ownerUserId !== userId) {
      throw new NotFoundException('角色不存在');
    }
    const updated = await this.prisma.character.update({
      where: { id },
      data: {
        name: dto.name?.trim() ? dto.name.trim().slice(0, 24) : undefined,
      },
    });
    return this.map(updated);
  }

  async getOwned(userId: string, characterId: string) {
    const c = await this.prisma.character.findUnique({
      where: { id: characterId },
    });
    if (!c || c.ownerUserId !== userId) {
      throw new NotFoundException('角色不存在');
    }
    return c;
  }
}
