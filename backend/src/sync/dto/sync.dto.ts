import { IsArray, IsEnum, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export enum ConflictResolution {
  KEEP_LOCAL = 'KEEP_LOCAL',
  KEEP_REMOTE = 'KEEP_REMOTE',
  CREATE_NEW_VERSION = 'CREATE_NEW_VERSION',
}

export class SyncClientItemDto {
  @IsString()
  @IsNotEmpty()
  documentId: string;

  @IsString()
  @IsOptional()
  checksum?: string;

  @IsOptional()
  versionNumber?: number;
}

export class StartSyncDto {
  @IsString()
  @IsOptional()
  deviceId?: string;

  @IsArray()
  @IsOptional()
  items?: SyncClientItemDto[];
}

export class ResolveConflictDto {
  @IsString()
  @IsNotEmpty()
  conflictId: string;

  @IsEnum(ConflictResolution)
  @IsNotEmpty()
  resolution: ConflictResolution;

  @IsOptional()
  changeNotes?: string;
}
