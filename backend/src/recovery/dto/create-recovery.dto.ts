import { IsEmail, IsInt, IsNotEmpty, IsOptional, Min } from 'class-validator';

export class CreateRecoveryDto {
  @IsEmail({}, { message: 'Valid delegate email is required' })
  @IsNotEmpty({ message: 'delegateEmail cannot be empty' })
  delegateEmail: string;

  @IsOptional()
  recoveryPayload?: Record<string, any>;

  @IsOptional()
  @IsInt()
  @Min(1)
  expiresInDays?: number;
}
