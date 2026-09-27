import {
  IsArray,
  IsBoolean,
  IsEmail,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';

export class CreateUserShareDto {
  @IsString()
  @IsNotEmpty({ message: 'documentId is required' })
  documentId: string;

  @IsOptional()
  @IsEmail({}, { message: 'Recipient must be a valid email' })
  recipientEmail?: string;

  @IsOptional()
  @IsString()
  recipientUserId?: string;

  @IsOptional()
  @IsArray()
  permissions?: string[];

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

  @IsOptional()
  keyEnvelope?: Record<string, any>;
}
