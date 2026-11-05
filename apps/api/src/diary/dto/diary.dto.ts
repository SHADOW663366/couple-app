import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateDiaryDto {
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  text?: string;

  @IsIn(['private', 'shared', 'joint'])
  visibility!: 'private' | 'shared' | 'joint';

  @IsOptional()
  @IsString()
  @MaxLength(80)
  title?: string;
}

export class AppendDiaryDto {
  @IsString()
  @MaxLength(2000)
  text!: string;
}
