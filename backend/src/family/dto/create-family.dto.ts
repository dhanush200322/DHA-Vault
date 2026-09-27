import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateFamilyDto {
  @IsString()
  @IsNotEmpty({ message: 'Family vault name is required' })
  name: string;

  @IsOptional()
  settings?: Record<string, any>;
}
