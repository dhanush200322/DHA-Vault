import { IsEmail, IsEnum, IsNotEmpty, IsOptional } from 'class-validator';

export class InviteMemberDto {
  @IsEmail({}, { message: 'Valid email address is required' })
  @IsNotEmpty({ message: 'Email cannot be empty' })
  email: string;

  @IsOptional()
  @IsEnum(['MEMBER', 'VIEWER'], { message: 'Role must be either MEMBER or VIEWER' })
  role?: 'MEMBER' | 'VIEWER';
}
