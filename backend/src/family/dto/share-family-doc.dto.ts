import { IsArray, IsOptional, IsString } from 'class-validator';

export class ShareFamilyDocDto {
  @IsOptional()
  @IsString()
  targetUserId?: string;

  @IsOptional()
  @IsArray()
  permissions?: string[];
}
