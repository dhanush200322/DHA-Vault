import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateProfileDto } from './dto/update-profile.dto';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async getMe(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        createdAt: true,
        profile: {
          select: {
            fullName: true,
            phone: true,
            avatarUrl: true,
            bio: true,
            createdAt: true,
            updatedAt: true,
          },
        },
        securitySettings: {
          select: {
            isPinEnabled: true,
            isBiometricEnabled: true,
            autoLockSeconds: true,
            twoFactorEnabled: true,
          },
        },
      },
    });

    if (!user) {
      throw new NotFoundException('User profile not found');
    }

    return user;
  }

  async updateMe(userId: string, dto: UpdateProfileDto) {
    await this.prisma.profile.upsert({
      where: { userId },
      update: {
        ...(dto.fullName !== undefined && { fullName: dto.fullName }),
        ...(dto.phone !== undefined && { phone: dto.phone }),
        ...(dto.bio !== undefined && { bio: dto.bio }),
      },
      create: {
        userId,
        fullName: dto.fullName || null,
        phone: dto.phone || null,
        bio: dto.bio || null,
      },
    });

    return this.getMe(userId);
  }
}
