import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  UploadedFiles,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { AppendDiaryDto, CreateDiaryDto } from './dto/diary.dto';
import { DiaryService, UploadedDiaryFile } from './diary.service';

@Controller('diary')
@UseGuards(JwtAuthGuard)
export class DiaryController {
  constructor(private readonly diary: DiaryService) {}

  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.diary.list(user.id);
  }

  @Get(':id')
  one(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.diary.getOne(user.id, id);
  }

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateDiaryDto) {
    return this.diary.create(user.id, dto);
  }

  @Post(':id/share')
  share(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.diary.share(user.id, id);
  }

  @Post(':id/append')
  append(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AppendDiaryDto,
  ) {
    return this.diary.append(user.id, id, dto.text);
  }

  @Post(':id/media')
  @UseInterceptors(
    FilesInterceptor('files', 6, {
      storage: memoryStorage(),
      limits: { fileSize: 8 * 1024 * 1024 },
    }),
  )
  addMedia(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @UploadedFiles() files?: Express.Multer.File[],
  ) {
    return this.diary.addMedia(
      user.id,
      id,
      (files ?? []) as UploadedDiaryFile[],
    );
  }
}
