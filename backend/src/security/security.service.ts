import { BadRequestException, Injectable, UnauthorizedException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService, AuditAction } from '../audit/audit.service';

@Injectable()
export class SecurityService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
  ) {}

  async getSettings(userId: string) {
    const settings = await this.prisma.securitySettings.findUnique({
      where: { userId },
      select: {
        isPinEnabled: true,
        isBiometricEnabled: true,
        autoLockSeconds: true,
        twoFactorEnabled: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    if (!settings) {
      return this.prisma.securitySettings.create({
        data: { userId },
        select: {
          isPinEnabled: true,
          isBiometricEnabled: true,
          autoLockSeconds: true,
          twoFactorEnabled: true,
          createdAt: true,
          updatedAt: true,
        },
      });
    }

    return settings;
  }

  async updateSettings(
    userId: string,
    options: {
      pin?: string;
      isPinEnabled?: boolean;
      isBiometricEnabled?: boolean;
      autoLockSeconds?: number;
    },
    ipAddress?: string,
    userAgent?: string,
  ) {
    const data: any = {};

    if (options.pin !== undefined) {
      if (options.pin && options.pin.length >= 4) {
        data.pinHash = await bcrypt.hash(options.pin, 10);
        data.isPinEnabled = true;
      } else if (options.pin === '') {
        data.pinHash = null;
        data.isPinEnabled = false;
      } else {
        throw new BadRequestException('PIN must be at least 4 digits');
      }
    }

    if (options.isPinEnabled !== undefined) {
      data.isPinEnabled = options.isPinEnabled;
    }

    if (options.isBiometricEnabled !== undefined) {
      data.isBiometricEnabled = options.isBiometricEnabled;
    }

    if (options.autoLockSeconds !== undefined) {
      data.autoLockSeconds = options.autoLockSeconds;
    }

    const updated = await this.prisma.securitySettings.upsert({
      where: { userId },
      update: data,
      create: { userId, ...data },
      select: {
        isPinEnabled: true,
        isBiometricEnabled: true,
        autoLockSeconds: true,
        twoFactorEnabled: true,
      },
    });

    await this.auditService.log({
      userId,
      action: AuditAction.SECURITY_CHANGE,
      ipAddress,
      userAgent,
      metadata: {
        isPinEnabled: updated.isPinEnabled,
        isBiometricEnabled: updated.isBiometricEnabled,
        autoLockSeconds: updated.autoLockSeconds,
      },
    });

    return updated;
  }

  async verifyPin(userId: string, pin: string) {
    const settings = await this.prisma.securitySettings.findUnique({
      where: { userId },
    });

    if (!settings || !settings.pinHash) {
      throw new BadRequestException('PIN lock is not configured');
    }

    const isValid = await bcrypt.compare(pin, settings.pinHash);
    if (!isValid) {
      throw new UnauthorizedException('Invalid vault PIN');
    }

    return { valid: true };
  }
}
