import { IsString, Length } from 'class-validator';

export class AcceptInviteDto {
  @IsString()
  @Length(6, 8)
  code!: string;
}
