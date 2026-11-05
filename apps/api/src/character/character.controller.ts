import { Body, Controller, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { CharacterService } from './character.service';
import { CreateCharacterDto, UpdateCharacterDto } from './dto/character.dto';

@Controller('characters')
@UseGuards(JwtAuthGuard)
export class CharacterController {
  constructor(private readonly characters: CharacterService) {}

  @Get('presets')
  presets() {
    return this.characters.presets();
  }

  @Get('me')
  me(@CurrentUser() user: AuthUser) {
    return this.characters.myCharacter(user.id);
  }

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateCharacterDto) {
    return this.characters.create(user.id, dto);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateCharacterDto,
  ) {
    return this.characters.update(user.id, id, dto);
  }
}
