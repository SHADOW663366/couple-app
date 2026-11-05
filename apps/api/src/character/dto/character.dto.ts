import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class CreateCharacterDto {
  @IsString()
  @MinLength(1)
  @MaxLength(40)
  artKey!: string;

  @IsOptional()
  @IsString()
  @MaxLength(24)
  name?: string;
}

export class UpdateCharacterDto {
  @IsOptional()
  @IsString()
  @MaxLength(24)
  name?: string;
}
