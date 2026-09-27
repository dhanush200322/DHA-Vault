import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class RegisterDeviceDto {
  @IsString()
  @IsNotEmpty()
  deviceId: string;

  @IsString()
  @IsNotEmpty()
  deviceName: string;

  @IsString()
  @IsNotEmpty()
  platform: string;

  @IsString()
  @IsOptional()
  pushToken?: string;

  @IsString()
  @IsOptional()
  appVersion?: string;
}
