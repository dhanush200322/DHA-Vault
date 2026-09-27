import { IsInt, IsNotEmpty, IsOptional, IsString, Min } from 'class-validator';

export class CreateVersionDto {
  @IsString()
  @IsNotEmpty()
  storagePath: string;

  @IsInt()
  @Min(0)
  fileSize: number;

  @IsString()
  @IsOptional()
  checksum?: string;

  @IsString()
  @IsOptional()
  changeNotes?: string;

  @IsString()
  @IsOptional()
  deviceId?: string;
}
