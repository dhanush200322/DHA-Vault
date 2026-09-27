import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  Min,
} from 'class-validator';

export enum DocumentType {
  PASSPORT = 'PASSPORT',
  AADHAAR = 'AADHAAR',
  PAN = 'PAN',
  DRIVING_LICENCE = 'DRIVING_LICENCE',
  DRIVERS_LICENSE = 'DRIVERS_LICENSE',
  NATIONAL_ID = 'NATIONAL_ID',
  VEHICLE = 'VEHICLE',
  INSURANCE = 'INSURANCE',
  EDUCATION_CERTIFICATE = 'EDUCATION_CERTIFICATE',
  MARKSHEET = 'MARKSHEET',
  EMPLOYMENT = 'EMPLOYMENT',
  BANK = 'BANK',
  MEDICAL = 'MEDICAL',
  PROPERTY = 'PROPERTY',
  RECEIPT = 'RECEIPT',
  CONTRACT = 'CONTRACT',
  CERTIFICATE = 'CERTIFICATE',
  INVOICE = 'INVOICE',
  TAX = 'TAX',
  OTHER = 'OTHER',
}

export class CreateDocumentDto {
  @IsString()
  @IsNotEmpty({ message: 'Document title is required' })
  title: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsUUID('4', { message: 'Category ID must be a valid UUID' })
  categoryId?: string;

  @IsOptional()
  @IsEnum(DocumentType, { message: 'Invalid document type' })
  documentType?: string = DocumentType.OTHER;

  @IsString()
  @IsNotEmpty({ message: 'Storage path is required' })
  storagePath: string;

  @IsOptional()
  @IsString()
  originalFileName?: string;

  @IsOptional()
  @IsString()
  mimeType?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  fileSize?: number;

  @IsOptional()
  @IsString()
  fileType?: string;

  @IsOptional()
  @IsString()
  thumbnailPath?: string;

  @IsOptional()
  @IsDateString()
  issueDate?: string;

  @IsOptional()
  @IsDateString()
  expiryDate?: string;

  @IsOptional()
  @IsBoolean()
  isFavorite?: boolean = false;

  @IsOptional()
  @IsBoolean()
  isEncrypted?: boolean = false;

  @IsOptional()
  @IsString()
  extractedText?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  tags?: string[];

  @IsOptional()
  @IsString()
  checksum?: string;

  @IsOptional()
  @IsString()
  deviceId?: string;
}
