import {
  IsArray,
  IsEmail,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';

export class CreateEmergencyDto {
  @IsEmail({}, { message: 'Valid delegate email is required' })
  @IsNotEmpty({ message: 'delegateEmail cannot be empty' })
  delegateEmail: string;

  @IsOptional()
  @IsString()
  delegateUserId?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  activationDelayHours?: number; // e.g. 48 hours (can be 0 in testing)

  @IsOptional()
  @IsEnum(['ALL', 'SELECTED_DOCUMENTS', 'CATEGORIES', 'FAMILY_DOCUMENTS'])
  scope?: 'ALL' | 'SELECTED_DOCUMENTS' | 'CATEGORIES' | 'FAMILY_DOCUMENTS';

  @IsOptional()
  @IsArray()
  selectedDocIds?: string[];

  @IsOptional()
  @IsString()
  notes?: string;
}
