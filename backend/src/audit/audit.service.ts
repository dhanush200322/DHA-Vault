import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

export enum AuditAction {
  LOGIN = 'LOGIN',
  LOGOUT = 'LOGOUT',
  DOCUMENT_UPLOAD = 'DOCUMENT_UPLOAD',
  DOCUMENT_VIEW = 'DOCUMENT_VIEW',
  DOCUMENT_UPDATE = 'DOCUMENT_UPDATE',
  DOCUMENT_DELETE = 'DOCUMENT_DELETE',
  DOCUMENT_DOWNLOAD = 'DOCUMENT_DOWNLOAD',
  DOCUMENT_SHARE = 'DOCUMENT_SHARE',
  SHARE_ACCESS = 'SHARE_ACCESS',
  SHARE_REVOKE = 'SHARE_REVOKE',
  DEVICE_ADD = 'DEVICE_ADD',
  DEVICE_REVOKE = 'DEVICE_REVOKE',
  DEVICE_REGISTERED = 'DEVICE_REGISTERED',
  BACKUP_STARTED = 'BACKUP_STARTED',
  BACKUP_COMPLETED = 'BACKUP_COMPLETED',
  BACKUP_FAILED = 'BACKUP_FAILED',
  DOCUMENT_SYNCED = 'DOCUMENT_SYNCED',
  SYNC_CONFLICT = 'SYNC_CONFLICT',
  REMOTE_LOCK = 'REMOTE_LOCK',
  RESTORE_STARTED = 'RESTORE_STARTED',
  RESTORE_COMPLETED = 'RESTORE_COMPLETED',
  SECURITY_CHANGE = 'SECURITY_CHANGE',
  // Phase 5 Audit Actions
  DOCUMENT_SHARED = 'DOCUMENT_SHARED',
  SHARE_OPENED = 'SHARE_OPENED',
  SHARE_DOWNLOADED = 'SHARE_DOWNLOADED',
  SHARE_REVOKED = 'SHARE_REVOKED',
  SHARE_EXPIRED = 'SHARE_EXPIRED',
  SHARE_MAX_VIEWS_REACHED = 'SHARE_MAX_VIEWS_REACHED',
  FAMILY_CREATED = 'FAMILY_CREATED',
  FAMILY_INVITATION_SENT = 'FAMILY_INVITATION_SENT',
  FAMILY_INVITATION_ACCEPTED = 'FAMILY_INVITATION_ACCEPTED',
  FAMILY_MEMBER_REMOVED = 'FAMILY_MEMBER_REMOVED',
  FAMILY_ROLE_CHANGED = 'FAMILY_ROLE_CHANGED',
  FAMILY_DOCUMENT_SHARED = 'FAMILY_DOCUMENT_SHARED',
  FAMILY_DOCUMENT_REVOKED = 'FAMILY_DOCUMENT_REVOKED',
  EMERGENCY_ACCESS_CREATED = 'EMERGENCY_ACCESS_CREATED',
  EMERGENCY_ACCESS_TRIGGERED = 'EMERGENCY_ACCESS_TRIGGERED',
  EMERGENCY_ACCESS_REVOKED = 'EMERGENCY_ACCESS_REVOKED',
  RECOVERY_DELEGATION_CREATED = 'RECOVERY_DELEGATION_CREATED',
  RECOVERY_DELEGATION_ACCEPTED = 'RECOVERY_DELEGATION_ACCEPTED',
  RECOVERY_DELEGATION_REVOKED = 'RECOVERY_DELEGATION_REVOKED',
}

export interface LogAuditOptions {
  userId: string;
  action: AuditAction | string;
  documentId?: string;
  ipAddress?: string;
  userAgent?: string;
  metadata?: Record<string, any>;
}

@Injectable()
export class AuditService {
  private readonly logger = new Logger(AuditService.name);

  constructor(private readonly prisma: PrismaService) {}

  async log(options: LogAuditOptions) {
    try {
      const sanitizedMeta = this.sanitizeMetadata(options.metadata);

      await this.prisma.documentAccessLog.create({
        data: {
          userId: options.userId,
          action: options.action,
          documentId: options.documentId || null,
          ipAddress: options.ipAddress || null,
          userAgent: options.userAgent || null,
          metadata: sanitizedMeta || undefined,
        },
      });
    } catch (err: any) {
      // Audit log failures should not crash the core application flow, but must be logged to stderr
      this.logger.error(`Failed to record audit log: ${err.message}`, err.stack);
    }
  }

  private sanitizeMetadata(metadata?: Record<string, any>): Record<string, any> | undefined {
    if (!metadata) return undefined;
    const sanitized: Record<string, any> = {};
    const prohibitedKeys = [
      'password',
      'passwordhash',
      'token',
      'refreshtoken',
      'secret',
      'accesstoken',
      'jwt',
      'pin',
      'twofactorsecret',
      'content',
      'extractedtext',
      'encryptionkey',
      'masterkey',
      'wrappedkey',
      's3_secret_key',
      's3_access_key',
      'secretkey',
      'accesskey',
    ];

    for (const [key, val] of Object.entries(metadata)) {
      if (prohibitedKeys.includes(key.toLowerCase())) {
        sanitized[key] = '[REDACTED]';
      } else if (typeof val === 'object' && val !== null) {
        sanitized[key] = this.sanitizeMetadata(val);
      } else {
        sanitized[key] = val;
      }
    }
    return sanitized;
  }
}
