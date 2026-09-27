import { IsEnum, IsNotEmpty } from 'class-validator';

export class UpdateRoleDto {
  @IsNotEmpty({ message: 'Role is required' })
  @IsEnum(['OWNER', 'MEMBER', 'VIEWER'], { message: 'Role must be OWNER, MEMBER, or VIEWER' })
  role: 'OWNER' | 'MEMBER' | 'VIEWER';
}
