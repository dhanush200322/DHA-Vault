import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService, AuditAction } from '../audit/audit.service';
import { RegisterDeviceDto } from './dto/register-device.dto';

@Injectable()
export class DevicesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
  ) {}

  async findAll(userId: string) {
    return this.prisma.device.findMany({
      where: { userId },
      orderBy: { lastActiveAt: 'desc' },
    });
  }

  async register(
    userId: string,
    dto: RegisterDeviceDto,
    ipAddress?: string,
    userAgent?: string,
  ) {
    const device = await this.prisma.device.upsert({
      where: { userId_deviceId: { userId, deviceId: dto.deviceId } },
      update: {
        deviceName: dto.deviceName,
        platform: dto.platform,
        pushToken: dto.pushToken || undefined,
        appVersion: dto.appVersion || undefined,
        lastActiveAt: new Date(),
        isLocked: false,
      },
      create: {
        userId,
        deviceId: dto.deviceId,
        deviceName: dto.deviceName,
        platform: dto.platform,
        pushToken: dto.pushToken || null,
        appVersion: dto.appVersion || null,
        isTrusted: true,
        isLocked: false,
      },
    });

    await this.auditService.log({
      userId,
      action: AuditAction.DEVICE_REGISTERED,
      ipAddress,
      userAgent,
      metadata: { deviceId: dto.deviceId, deviceName: dto.deviceName, platform: dto.platform },
    });

    return device;
  }

  async setTrust(userId: string, deviceId: string, isTrusted: boolean) {
    const device = await this.prisma.device.findUnique({
      where: { userId_deviceId: { userId, deviceId } },
    });

    if (!device) {
      throw new NotFoundException('Device not found');
    }

    return this.prisma.device.update({
      where: { id: device.id },
      data: { isTrusted },
    });
  }

  async revoke(userId: string, deviceId: string, ipAddress?: string, userAgent?: string) {
    const device = await this.prisma.device.findUnique({
      where: { userId_deviceId: { userId, deviceId } },
    });

    if (!device) {
      throw new NotFoundException('Device not found');
    }

    await this.prisma.$transaction([
      this.prisma.device.delete({
        where: { id: device.id },
      }),
      this.prisma.refreshToken.updateMany({
        where: { userId, deviceId },
        data: { revokedAt: new Date() },
      }),
    ]);

    await this.auditService.log({
      userId,
      action: AuditAction.DEVICE_REVOKE,
      ipAddress,
      userAgent,
      metadata: { deviceId, deviceName: device.deviceName },
    });

    return { success: true, message: 'Device revoked successfully' };
  }

  async remoteLock(userId: string, deviceId: string, ipAddress?: string, userAgent?: string) {
    const device = await this.prisma.device.findUnique({
      where: { userId_deviceId: { userId, deviceId } },
    });

    if (!device) {
      throw new NotFoundException('Device not found');
    }

    await this.prisma.$transaction([
      this.prisma.device.update({
        where: { id: device.id },
        data: { isLocked: true },
      }),
      this.prisma.refreshToken.updateMany({
        where: { userId, deviceId },
        data: { revokedAt: new Date() },
      }),
    ]);

    await this.auditService.log({
      userId,
      action: AuditAction.REMOTE_LOCK,
      ipAddress,
      userAgent,
      metadata: { deviceId, deviceName: device.deviceName },
    });

    return {
      success: true,
      message: 'Device locked remotely. Access tokens invalidated.',
      device: {
        id: device.id,
        deviceId: device.deviceId,
        isLocked: true,
      },
    };
  }

  async checkDeviceStatus(userId: string, deviceId: string) {
    const device = await this.prisma.device.findUnique({
      where: { userId_deviceId: { userId, deviceId } },
    });

    if (!device) {
      return { exists: false, isTrusted: false, isLocked: false };
    }

    return {
      exists: true,
      isTrusted: device.isTrusted,
      isLocked: device.isLocked,
      syncStatus: device.syncStatus,
      lastSyncedAt: device.lastSyncedAt,
    };
  }
}
