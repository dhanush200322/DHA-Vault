import { IsOptional, IsString } from 'class-validator';

export class RestoreBackupDto {
  @IsString()
  @IsOptional()
  backupId?: string;

  @IsString()
  @IsOptional()
  passphrase?: string;
}
