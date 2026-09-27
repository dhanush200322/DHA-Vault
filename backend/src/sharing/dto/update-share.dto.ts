import { IsBoolean, IsInt, IsOptional, IsString, Min } from 'class-validator';

export class UpdateShareDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  expiresInHours?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  maxViews?: number;

  @IsOptional()
  @IsBoolean()
  allowDownload?: boolean;

  @IsOptional()
  @IsString()
  watermarkText?: string;
}
