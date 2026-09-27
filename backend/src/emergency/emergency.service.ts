import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService, AuditAction } from '../audit/audit.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CreateEmergencyDto } from './dto/create-emergency.dto';

@Injectable()
export class EmergencyService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
    private readonly notificationsService: NotificationsService,
  ) {}

  async create(userId: string, dto: CreateEmergencyDto, ipAddress?: string, userAgent?: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    const targetEmail = dto.delegateEmail.trim().toLowerCase();

    if (user?.email.toLowerCase() === targetEmail) {
      throw new BadRequestException('You cannot designate yourself as an emergency delegate');
    }

    let delegateUserId = dto.delegateUserId;
    const delegateUser = await this.prisma.user.findUnique({
      where: { email: targetEmail },
    });
    if (delegateUser) {
      delegateUserId = delegateUser.id;
    }

    const delay = dto.activationDelayHours !== undefined ? dto.activationDelayHours : 48;
    const scope = dto.scope || 'SELECTED_DOCUMENTS';

    const emergency = await this.prisma.emergencyAccess.create({
      data: {
        ownerId: userId,
        delegateEmail: targetEmail,
        delegateUserId: delegateUserId || null,
        status: 'ACTIVE',
        activationDelayHours: delay,
        scope,
        selectedDocIds: dto.selectedDocIds || [],
        notes: dto.notes || null,
      },
      include: {
        delegateUser: { select: { id: true, email: true, profile: true } },
      },
    });

    await this.auditService.log({
      userId,
      action: AuditAction.EMERGENCY_ACCESS_CREATED,
      ipAddress,
      userAgent,
      metadata: {
        emergencyId: emergency.id,
        delegateEmail: targetEmail,
        activationDelayHours: delay,
        scope,
      },
    });

    if (delegateUserId) {
      await this.notificationsService.createNotification(
        delegateUserId,
        'Emergency Delegate Designation',
        `You have been designated as an emergency contact for ${user?.email}.`,
        'EMERGENCY_DELEGATE',
        { emergencyId: emergency.id },
      );
    }

    return emergency;
  }

  async findAll(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });

    const delegations = await this.prisma.emergencyAccess.findMany({
      where: {
        OR: [
          { ownerId: userId },
          { delegateUserId: userId },
          ...(user?.email ? [{ delegateEmail: user.email.toLowerCase() }] : []),
        ],
      },
      include: {
        owner: { select: { id: true, email: true, profile: true } },
        delegateUser: { select: { id: true, email: true, profile: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    return Promise.all(delegations.map((d) => this.evaluateActivationState(d)));
  }

  async findOne(userId: string, id: string) {
    const emergency = await this.prisma.emergencyAccess.findUnique({
      where: { id },
      include: {
        owner: { select: { id: true, email: true, profile: true } },
        delegateUser: { select: { id: true, email: true, profile: true } },
      },
    });

    if (!emergency) {
      throw new NotFoundException('Emergency access record not found');
    }

    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    const isOwner = emergency.ownerId === userId;
    const isDelegate =
      emergency.delegateUserId === userId ||
      (user?.email && emergency.delegateEmail.toLowerCase() === user.email.toLowerCase());

    if (!isOwner && !isDelegate) {
      throw new ForbiddenException('You do not have access to this emergency record');
    }

    return this.evaluateActivationState(emergency);
  }

  async activate(userId: string, id: string, ipAddress?: string, userAgent?: string) {
    const emergency = await this.findOne(userId, id);

    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    const isDelegate =
      emergency.delegateUserId === userId ||
      (user?.email && emergency.delegateEmail.toLowerCase() === user.email.toLowerCase());

    if (!isDelegate) {
      throw new ForbiddenException('Only the designated emergency delegate can trigger activation');
    }

    if (emergency.status !== 'ACTIVE' && emergency.status !== 'PENDING') {
      throw new BadRequestException(`Cannot activate emergency access with status: ${emergency.status}`);
    }

    const now = new Date();
    const isImmediate = emergency.activationDelayHours === 0;

    const updated = await this.prisma.emergencyAccess.update({
      where: { id },
      data: {
        status: isImmediate ? 'COMPLETED' : 'TRIGGERED',
        triggerRequestedAt: now,
        activatedAt: isImmediate ? now : null,
      },
    });

    await this.auditService.log({
      userId,
      action: AuditAction.EMERGENCY_ACCESS_TRIGGERED,
      ipAddress,
      userAgent,
      metadata: {
        emergencyId: id,
        activationDelayHours: emergency.activationDelayHours,
        isImmediate,
      },
    });

    // Send high-priority notification to vault owner
    await this.notificationsService.createNotification(
      emergency.ownerId,
      'URGENT: Emergency Access Triggered',
      `Emergency access to your vault has been requested by ${emergency.delegateEmail}. If this is unauthorized, cancel it immediately before the waiting window closes.`,
      'EMERGENCY_TRIGGERED',
      { emergencyId: id, waitingHours: emergency.activationDelayHours },
    );

    return this.evaluateActivationState(updated);
  }

  async cancel(userId: string, id: string, ipAddress?: string, userAgent?: string) {
    const emergency = await this.findOne(userId, id);

    if (emergency.ownerId !== userId) {
      throw new ForbiddenException('Only the vault owner can cancel emergency access activation');
    }

    const updated = await this.prisma.emergencyAccess.update({
      where: { id },
      data: {
        status: 'ACTIVE',
        triggerRequestedAt: null,
        activatedAt: null,
      },
    });

    await this.auditService.log({
      userId,
      action: AuditAction.EMERGENCY_ACCESS_REVOKED,
      ipAddress,
      userAgent,
      metadata: { emergencyId: id, action: 'EMERGENCY_TRIGGER_CANCELLED' },
    });

    if (emergency.delegateUserId) {
      await this.notificationsService.createNotification(
        emergency.delegateUserId,
        'Emergency Request Cancelled',
        `The emergency access request was cancelled by the vault owner.`,
        'EMERGENCY_CANCELLED',
        { emergencyId: id },
      );
    }

    return { success: true, message: 'Emergency access request cancelled by owner', emergency: updated };
  }

  async revoke(userId: string, id: string, ipAddress?: string, userAgent?: string) {
    const emergency = await this.findOne(userId, id);

    if (emergency.ownerId !== userId) {
      throw new ForbiddenException('Only the vault owner can revoke emergency access');
    }

    const updated = await this.prisma.emergencyAccess.update({
      where: { id },
      data: { status: 'REVOKED' },
    });

    await this.auditService.log({
      userId,
      action: AuditAction.EMERGENCY_ACCESS_REVOKED,
      ipAddress,
      userAgent,
      metadata: { emergencyId: id },
    });

    return { success: true, message: 'Emergency access permanently revoked', emergency: updated };
  }

  async getScopedDocuments(userId: string, id: string) {
    const emergency = await this.findOne(userId, id);

    if (emergency.status !== 'COMPLETED') {
      throw new ForbiddenException(
        `Emergency access is not currently activated (current status: ${emergency.status}, waiting period remaining: ${emergency.remainingSeconds}s)`,
      );
    }

    const selectedDocIds = (emergency.selectedDocIds as string[]) || [];

    if (selectedDocIds.length === 0) {
      return [];
    }

    const documents = await this.prisma.document.findMany({
      where: {
        id: { in: selectedDocIds },
        userId: emergency.ownerId,
        isArchived: false,
      },
      include: {
        category: { select: { id: true, name: true, icon: true, color: true } },
        files: true,
      },
    });

    return documents;
  }

  private async evaluateActivationState(emergency: any) {
    let currentStatus = emergency.status;
    let isFullyActivated = currentStatus === 'COMPLETED';
    let remainingSeconds = 0;

    if (currentStatus === 'TRIGGERED' && emergency.triggerRequestedAt) {
      const triggerTime = new Date(emergency.triggerRequestedAt).getTime();
      const delayMs = emergency.activationDelayHours * 60 * 60 * 1000;
      const activationTime = triggerTime + delayMs;
      const now = Date.now();

      if (now >= activationTime) {
        // Delay elapsed! Automatically transition to COMPLETED
        currentStatus = 'COMPLETED';
        isFullyActivated = true;
        await this.prisma.emergencyAccess.update({
          where: { id: emergency.id },
          data: { status: 'COMPLETED', activatedAt: new Date(activationTime) },
        });
      } else {
        remainingSeconds = Math.max(0, Math.floor((activationTime - now) / 1000));
      }
    }

    return {
      ...emergency,
      status: currentStatus,
      isFullyActivated,
      remainingSeconds,
    };
  }
}
