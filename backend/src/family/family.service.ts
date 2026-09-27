import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import * as crypto from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService, AuditAction } from '../audit/audit.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CreateFamilyDto } from './dto/create-family.dto';
import { UpdateFamilyDto } from './dto/update-family.dto';
import { InviteMemberDto } from './dto/invite-member.dto';
import { UpdateRoleDto } from './dto/update-role.dto';
import { ShareFamilyDocDto } from './dto/share-family-doc.dto';

@Injectable()
export class FamilyService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
    private readonly notificationsService: NotificationsService,
  ) {}

  async create(userId: string, dto: CreateFamilyDto, ipAddress?: string, userAgent?: string) {
    const family = await this.prisma.familyVault.create({
      data: {
        name: dto.name.trim(),
        ownerId: userId,
        status: 'ACTIVE',
        settings: dto.settings || undefined,
        members: {
          create: {
            userId,
            role: 'OWNER',
            status: 'ACTIVE',
            joinedAt: new Date(),
          },
        },
      },
      include: {
        members: {
          include: {
            user: {
              select: { id: true, email: true, profile: true },
            },
          },
        },
      },
    });

    await this.auditService.log({
      userId,
      action: AuditAction.FAMILY_CREATED,
      ipAddress,
      userAgent,
      metadata: { familyVaultId: family.id, name: family.name },
    });

    return family;
  }

  async findAll(userId: string) {
    return this.prisma.familyVault.findMany({
      where: {
        OR: [
          { ownerId: userId },
          {
            members: {
              some: {
                userId,
                status: 'ACTIVE',
              },
            },
          },
        ],
      },
      include: {
        owner: {
          select: { id: true, email: true, profile: true },
        },
        members: {
          where: { status: 'ACTIVE' },
          include: {
            user: {
              select: { id: true, email: true, profile: true },
            },
          },
        },
        _count: {
          select: {
            members: { where: { status: 'ACTIVE' } },
            documentAccess: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findOne(userId: string, familyId: string) {
    const family = await this.prisma.familyVault.findUnique({
      where: { id: familyId },
      include: {
        owner: {
          select: { id: true, email: true, profile: true },
        },
        members: {
          include: {
            user: {
              select: { id: true, email: true, profile: true },
            },
          },
        },
        _count: {
          select: {
            members: { where: { status: 'ACTIVE' } },
            documentAccess: true,
          },
        },
      },
    });

    if (!family) {
      throw new NotFoundException('Family vault not found');
    }

    const membership = family.members.find(
      (m) => m.userId === userId && m.status === 'ACTIVE',
    );
    if (!membership && family.ownerId !== userId) {
      throw new ForbiddenException('You do not have access to this family vault');
    }

    return {
      ...family,
      currentUserRole: family.ownerId === userId ? 'OWNER' : membership?.role,
    };
  }

  async update(
    userId: string,
    familyId: string,
    dto: UpdateFamilyDto,
    ipAddress?: string,
    userAgent?: string,
  ) {
    const family = await this.findOne(userId, familyId);
    if (family.currentUserRole !== 'OWNER') {
      throw new ForbiddenException('Only the family vault owner can update vault settings');
    }

    const updated = await this.prisma.familyVault.update({
      where: { id: familyId },
      data: {
        ...(dto.name && { name: dto.name.trim() }),
        ...(dto.status && { status: dto.status }),
        ...(dto.settings && { settings: dto.settings }),
      },
      include: {
        members: {
          include: {
            user: { select: { id: true, email: true, profile: true } },
          },
        },
      },
    });

    return updated;
  }

  async delete(userId: string, familyId: string, ipAddress?: string, userAgent?: string) {
    const family = await this.findOne(userId, familyId);
    if (family.currentUserRole !== 'OWNER') {
      throw new ForbiddenException('Only the family vault owner can delete this vault');
    }

    await this.prisma.familyVault.delete({
      where: { id: familyId },
    });

    await this.auditService.log({
      userId,
      action: AuditAction.FAMILY_MEMBER_REMOVED,
      ipAddress,
      userAgent,
      metadata: { familyVaultId: familyId, action: 'FAMILY_VAULT_DELETED' },
    });

    return { success: true, message: 'Family vault deleted successfully' };
  }

  async getMembers(userId: string, familyId: string) {
    await this.findOne(userId, familyId);

    return this.prisma.familyMembership.findMany({
      where: {
        familyVaultId: familyId,
        status: { in: ['ACTIVE', 'INVITED'] },
      },
      include: {
        user: {
          select: { id: true, email: true, profile: true },
        },
      },
      orderBy: [{ role: 'asc' }, { createdAt: 'asc' }],
    });
  }

  async createInvitation(
    userId: string,
    familyId: string,
    dto: InviteMemberDto,
    ipAddress?: string,
    userAgent?: string,
  ) {
    const family = await this.findOne(userId, familyId);
    if (family.currentUserRole !== 'OWNER') {
      throw new ForbiddenException('Only the family vault owner can invite members');
    }

    const targetEmail = dto.email.trim().toLowerCase();

    // Check if user is already a member
    const existingMembership = await this.prisma.familyMembership.findFirst({
      where: {
        familyVaultId: familyId,
        user: { email: targetEmail },
        status: 'ACTIVE',
      },
    });

    if (existingMembership) {
      throw new BadRequestException('User is already an active member of this family vault');
    }

    const rawToken = crypto.randomBytes(32).toString('hex');
    const tokenHash = crypto.createHash('sha256').update(rawToken).digest('hex');
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days

    // Revoke any previous pending invitations for this email
    await this.prisma.familyInvitation.updateMany({
      where: {
        familyVaultId: familyId,
        email: targetEmail,
        status: 'PENDING',
      },
      data: { status: 'REVOKED' },
    });

    const invitation = await this.prisma.familyInvitation.create({
      data: {
        familyVaultId: familyId,
        email: targetEmail,
        tokenHash,
        role: dto.role || 'MEMBER',
        status: 'PENDING',
        expiresAt,
        invitedById: userId,
      },
    });

    await this.auditService.log({
      userId,
      action: AuditAction.FAMILY_INVITATION_SENT,
      ipAddress,
      userAgent,
      metadata: {
        familyVaultId: familyId,
        email: targetEmail,
        role: invitation.role,
      },
    });

    // Send in-app notification if user already registered
    const invitedUser = await this.prisma.user.findUnique({
      where: { email: targetEmail },
    });
    if (invitedUser) {
      await this.notificationsService.createNotification(
        invitedUser.id,
        'Family Vault Invitation',
        `You have been invited to join the "${family.name}" Family Vault as a ${invitation.role}.`,
        'FAMILY_INVITATION',
        { familyVaultId: familyId, invitationId: invitation.id, token: rawToken },
      );
    }

    return {
      id: invitation.id,
      familyVaultId: invitation.familyVaultId,
      email: invitation.email,
      role: invitation.role,
      status: invitation.status,
      expiresAt: invitation.expiresAt,
      token: rawToken, // Returned once for distribution
    };
  }

  async acceptInvitation(
    userId: string,
    token: string,
    ipAddress?: string,
    userAgent?: string,
  ) {
    const tokenHash = crypto.createHash('sha256').update(token.trim()).digest('hex');

    const invitation = await this.prisma.familyInvitation.findUnique({
      where: { tokenHash },
      include: { familyVault: true },
    });

    if (!invitation) {
      throw new NotFoundException('Invitation not found or invalid token');
    }

    if (invitation.status !== 'PENDING') {
      throw new BadRequestException(`Invitation is no longer active (status: ${invitation.status})`);
    }

    if (new Date() > invitation.expiresAt) {
      await this.prisma.familyInvitation.update({
        where: { id: invitation.id },
        data: { status: 'EXPIRED' },
      });
      throw new BadRequestException('Invitation has expired');
    }

    // Verify user email matches invitation email
    const currentUser = await this.prisma.user.findUnique({
      where: { id: userId },
    });

    if (currentUser?.email.toLowerCase() !== invitation.email.toLowerCase()) {
      throw new ForbiddenException(
        `This invitation was sent to ${invitation.email}. Please log in with that account.`,
      );
    }

    // Upsert membership
    await this.prisma.$transaction([
      this.prisma.familyMembership.upsert({
        where: {
          familyVaultId_userId: {
            familyVaultId: invitation.familyVaultId,
            userId,
          },
        },
        create: {
          familyVaultId: invitation.familyVaultId,
          userId,
          role: invitation.role,
          status: 'ACTIVE',
          invitedBy: invitation.invitedById,
          joinedAt: new Date(),
        },
        update: {
          role: invitation.role,
          status: 'ACTIVE',
          joinedAt: new Date(),
        },
      }),
      this.prisma.familyInvitation.update({
        where: { id: invitation.id },
        data: { status: 'ACCEPTED' },
      }),
    ]);

    await this.auditService.log({
      userId,
      action: AuditAction.FAMILY_INVITATION_ACCEPTED,
      ipAddress,
      userAgent,
      metadata: {
        familyVaultId: invitation.familyVaultId,
        role: invitation.role,
      },
    });

    // Notify family owner
    await this.notificationsService.createNotification(
      invitation.familyVault.ownerId,
      'Family Member Joined',
      `${currentUser.email} has accepted your invitation and joined "${invitation.familyVault.name}".`,
      'FAMILY_MEMBER_JOINED',
      { familyVaultId: invitation.familyVaultId, userId },
    );

    return {
      success: true,
      message: `Successfully joined ${invitation.familyVault.name}`,
      familyVaultId: invitation.familyVaultId,
      role: invitation.role,
    };
  }

  async updateMemberRole(
    userId: string,
    familyId: string,
    targetUserId: string,
    dto: UpdateRoleDto,
    ipAddress?: string,
    userAgent?: string,
  ) {
    const family = await this.findOne(userId, familyId);
    if (family.currentUserRole !== 'OWNER') {
      throw new ForbiddenException('Only the family vault owner can change member roles');
    }

    if (family.ownerId === targetUserId && dto.role !== 'OWNER') {
      throw new BadRequestException('Cannot demote primary vault owner');
    }

    const membership = await this.prisma.familyMembership.findUnique({
      where: {
        familyVaultId_userId: {
          familyVaultId: familyId,
          userId: targetUserId,
        },
      },
    });

    if (!membership) {
      throw new NotFoundException('Member not found in this family vault');
    }

    const updated = await this.prisma.familyMembership.update({
      where: { id: membership.id },
      data: { role: dto.role },
      include: {
        user: { select: { id: true, email: true, profile: true } },
      },
    });

    await this.auditService.log({
      userId,
      action: AuditAction.FAMILY_ROLE_CHANGED,
      ipAddress,
      userAgent,
      metadata: {
        familyVaultId: familyId,
        targetUserId,
        oldRole: membership.role,
        newRole: dto.role,
      },
    });

    await this.notificationsService.createNotification(
      targetUserId,
      'Role Updated',
      `Your role in "${family.name}" has been changed to ${dto.role}.`,
      'FAMILY_ROLE_CHANGED',
      { familyVaultId: familyId, newRole: dto.role },
    );

    return updated;
  }

  async removeMember(
    userId: string,
    familyId: string,
    targetUserId: string,
    ipAddress?: string,
    userAgent?: string,
  ) {
    const family = await this.findOne(userId, familyId);
    const isOwner = family.currentUserRole === 'OWNER';
    const isSelf = userId === targetUserId;

    if (!isOwner && !isSelf) {
      throw new ForbiddenException('Only the owner can remove members, or a member can leave');
    }

    if (family.ownerId === targetUserId) {
      throw new BadRequestException('Primary vault owner cannot be removed from the family vault');
    }

    const membership = await this.prisma.familyMembership.findUnique({
      where: {
        familyVaultId_userId: {
          familyVaultId: familyId,
          userId: targetUserId,
        },
      },
    });

    if (!membership) {
      throw new NotFoundException('Member not found in family vault');
    }

    // Delete membership and their specific document access grants
    await this.prisma.$transaction([
      this.prisma.familyMembership.delete({
        where: { id: membership.id },
      }),
      this.prisma.familyDocumentAccess.deleteMany({
        where: {
          familyVaultId: familyId,
          targetUserId,
        },
      }),
    ]);

    await this.auditService.log({
      userId,
      action: AuditAction.FAMILY_MEMBER_REMOVED,
      ipAddress,
      userAgent,
      metadata: { familyVaultId: familyId, targetUserId },
    });

    return { success: true, message: 'Member removed from family vault' };
  }

  async getDocuments(userId: string, familyId: string) {
    const family = await this.findOne(userId, familyId);
    const userRole = family.currentUserRole;

    const accessList = await this.prisma.familyDocumentAccess.findMany({
      where: {
        familyVaultId: familyId,
        OR: [
          { targetUserId: null }, // shared with whole family
          { targetUserId: userId }, // shared specifically with this user
          { sharedById: userId }, // user shared it
        ],
      },
      include: {
        document: {
          include: {
            category: { select: { id: true, name: true, icon: true, color: true } },
            user: { select: { id: true, email: true, profile: true } },
            files: true,
          },
        },
        sharedBy: {
          select: { id: true, email: true, profile: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return accessList.map((item) => ({
      accessId: item.id,
      familyVaultId: item.familyVaultId,
      permissions: item.permissions,
      sharedAt: item.createdAt,
      sharedBy: item.sharedBy,
      targetUserId: item.targetUserId,
      document: item.document,
    }));
  }

  async shareDocument(
    userId: string,
    familyId: string,
    documentId: string,
    dto: ShareFamilyDocDto,
    ipAddress?: string,
    userAgent?: string,
  ) {
    const family = await this.findOne(userId, familyId);

    // VIEWER cannot share documents
    if (family.currentUserRole === 'VIEWER') {
      throw new ForbiddenException('Viewers do not have permission to share documents in the family vault');
    }

    // Verify document exists and belongs to user
    const document = await this.prisma.document.findUnique({
      where: { id: documentId },
    });

    if (!document) {
      throw new NotFoundException('Document not found');
    }

    if (document.userId !== userId) {
      throw new ForbiddenException('You can only share your own documents to the family vault');
    }

    const permissions = dto.permissions && dto.permissions.length > 0
      ? dto.permissions
      : ['VIEW', 'DOWNLOAD'];

    const existing = await this.prisma.familyDocumentAccess.findFirst({
      where: {
        familyVaultId: familyId,
        documentId,
        targetUserId: dto.targetUserId || null,
      },
    });

    let access;
    if (existing) {
      access = await this.prisma.familyDocumentAccess.update({
        where: { id: existing.id },
        data: { permissions },
        include: { document: true },
      });
    } else {
      access = await this.prisma.familyDocumentAccess.create({
        data: {
          familyVaultId: familyId,
          documentId,
          sharedById: userId,
          targetUserId: dto.targetUserId || null,
          permissions,
        },
        include: { document: true },
      });
    }

    await this.auditService.log({
      userId,
      action: AuditAction.FAMILY_DOCUMENT_SHARED,
      documentId,
      ipAddress,
      userAgent,
      metadata: {
        familyVaultId: familyId,
        targetUserId: dto.targetUserId || 'ALL',
        permissions,
      },
    });

    return access;
  }

  async revokeDocumentAccess(
    userId: string,
    familyId: string,
    documentId: string,
    targetUserId?: string,
    ipAddress?: string,
    userAgent?: string,
  ) {
    const family = await this.findOne(userId, familyId);

    const document = await this.prisma.document.findUnique({
      where: { id: documentId },
    });

    if (!document) {
      throw new NotFoundException('Document not found');
    }

    // Can revoke if document owner or family owner
    if (document.userId !== userId && family.currentUserRole !== 'OWNER') {
      throw new ForbiddenException('Only the document owner or family vault owner can revoke access');
    }

    await this.prisma.familyDocumentAccess.deleteMany({
      where: {
        familyVaultId: familyId,
        documentId,
        ...(targetUserId !== undefined && targetUserId !== 'all'
          ? { targetUserId }
          : {}),
      },
    });

    await this.auditService.log({
      userId,
      action: AuditAction.FAMILY_DOCUMENT_REVOKED,
      documentId,
      ipAddress,
      userAgent,
      metadata: { familyVaultId: familyId, targetUserId: targetUserId || 'ALL' },
    });

    return { success: true, message: 'Document access revoked from family vault' };
  }
}
