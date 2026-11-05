import { IsIn, IsInt, IsOptional, IsString, Max, MaxLength, Min, MinLength } from 'class-validator';

export class CreateTruthSessionDto {
  @IsIn(['solo', 'duo'])
  mode!: 'solo' | 'duo';

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(3)
  level?: number;
}

export class AnswerTruthDto {
  @IsString()
  @MinLength(1)
  @MaxLength(2000)
  answer!: string;
}
