import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService, AuditAction } from '../audit/audit.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CreateRecoveryDto } from './dto/create-recovery.dto';

@Injectable()
export class RecoveryService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
    private readonly notificationsService: NotificationsService,
  ) {}

  async create(userId: string, dto: CreateRecoveryDto, ipAddress?: string, userAgent?: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    const targetEmail = dto.delegateEmail.trim().toLowerCase();

    if (user?.email.toLowerCase() === targetEmail) {
      throw new BadRequestException('You cannot designate yourself as a recovery delegate');
    }

    let delegateUserId: string | null = null;
    const delegateUser = await this.prisma.user.findUnique({
      where: { email: targetEmail },
    });
    if (delegateUser) {
      delegateUserId = delegateUser.id;
    }

    const expiresAt = dto.expiresInDays
      ? new Date(Date.now() + dto.expiresInDays * 24 * 60 * 60 * 1000)
      : null;

    const delegation = await this.prisma.recoveryDelegation.create({
      data: {
        ownerId: userId,
        delegateEmail: targetEmail,
        delegateUserId,
        status: 'PENDING',
        recoveryPayload: dto.recoveryPayload || undefined,
        expiresAt,
      },
      include: {
        delegateUser: { select: { id: true, email: true, profile: true } },
      },
    });

    await this.auditService.log({
      userId,
      action: AuditAction.RECOVERY_DELEGATION_CREATED,
      ipAddress,
      userAgent,
      metadata: { delegationId: delegation.id, delegateEmail: targetEmail },
    });

    if (delegateUserId) {
      await this.notificationsService.createNotification(
        delegateUserId,
        'Account Recovery Delegation Request',
        `${user?.email} has requested you as an account recovery delegate.`,
        'RECOVERY_DELEGATION',
        { delegationId: delegation.id },
      );
    }

    return delegation;
  }

  async findAll(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });

    return this.prisma.recoveryDelegation.findMany({
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
  }

  async accept(userId: string, id: string, ipAddress?: string, userAgent?: string) {
    const delegation = await this.prisma.recoveryDelegation.findUnique({
      where: { id },
      include: { owner: true },
    });

    if (!delegation) {
      throw new NotFoundException('Recovery delegation not found');
    }

    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    const isTarget =
      delegation.delegateUserId === userId ||
      (user?.email && delegation.delegateEmail.toLowerCase() === user.email.toLowerCase());

    if (!isTarget) {
      throw new ForbiddenException('Only the designated delegate can accept this recovery request');
    }

    if (delegation.status !== 'PENDING') {
      throw new BadRequestException(`Cannot accept delegation with status: ${delegation.status}`);
    }

    const updated = await this.prisma.recoveryDelegation.update({
      where: { id },
      data: {
        status: 'ACTIVE',
        delegateUserId: userId,
        acceptedAt: new Date(),
      },
    });

    await this.auditService.log({
      userId,
      action: AuditAction.RECOVERY_DELEGATION_ACCEPTED,
      ipAddress,
      userAgent,
      metadata: { delegationId: id },
    });

    await this.notificationsService.createNotification(
      delegation.ownerId,
      'Recovery Delegation Accepted',
      `${delegation.delegateEmail} has accepted your recovery delegation request.`,
      'RECOVERY_ACCEPTED',
      { delegationId: id },
    );

    return { success: true, message: 'Recovery delegation accepted', delegation: updated };
  }

  async revoke(userId: string, id: string, ipAddress?: string, userAgent?: string) {
    const delegation = await this.prisma.recoveryDelegation.findUnique({
      where: { id },
    });

    if (!delegation) {
      throw new NotFoundException('Recovery delegation not found');
    }

    if (delegation.ownerId !== userId) {
      throw new ForbiddenException('Only the owner can revoke this recovery delegation');
    }

    const updated = await this.prisma.recoveryDelegation.update({
      where: { id },
      data: {
        status: 'REVOKED',
        revokedAt: new Date(),
      },
    });

    await this.auditService.log({
      userId,
      action: AuditAction.RECOVERY_DELEGATION_REVOKED,
      ipAddress,
      userAgent,
      metadata: { delegationId: id },
    });

    return { success: true, message: 'Recovery delegation revoked', delegation: updated };
  }
}
