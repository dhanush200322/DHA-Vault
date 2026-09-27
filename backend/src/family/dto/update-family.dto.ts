import { IsEnum, IsOptional, IsString } from 'class-validator';

export class UpdateFamilyDto {
  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsEnum(['ACTIVE', 'SUSPENDED', 'ARCHIVED'], { message: 'Invalid family vault status' })
  status?: string;

  @IsOptional()
  settings?: Record<string, any>;
}
