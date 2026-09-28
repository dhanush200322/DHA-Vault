import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { MailService } from './mail.service';
import { PrismaService } from '../prisma/prisma.service';

describe('MailService', () => {
  let service: MailService;
  let prismaService: any;
  let configService: any;

  beforeEach(async () => {
    prismaService = {
      notification: {
        findFirst: jest.fn(),
        create: jest.fn(),
      },
    };

    configService = {
      get: jest.fn((key: string, defaultValue?: any) => {
        const config: Record<string, any> = {
          SMTP_HOST: 'smtp.gmail.com',
          SMTP_PORT: 465,
          SMTP_SECURE: 'true',
          SMTP_USER: 'test@example.com',
          SMTP_APP_PASSWORD: 'test pass word 1234',
          SMTP_FROM_NAME: 'DHA Vault',
          SMTP_FROM_EMAIL: 'test@example.com',
        };
        return config[key] ?? defaultValue;
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MailService,
        { provide: PrismaService, useValue: prismaService },
        { provide: ConfigService, useValue: configService },
      ],
    }).compile();

    service = module.get<MailService>(MailService);
  });

  describe('resolveDisplayName', () => {
    it('prioritizes Google account display name', () => {
      const name = service.resolveDisplayName({
        fullName: 'Profile Name',
        googleFullName: 'Google Account Name',
        email: 'user@example.com',
      });
      expect(name).toBe('Google Account Name');
    });

    it('uses profile fullName when googleFullName is absent', () => {
      const name = service.resolveDisplayName({
        fullName: 'Jane Doe',
        googleFullName: null,
        email: 'janedoe@example.com',
      });
      expect(name).toBe('Jane Doe');
    });

    it('derives name from email when names are absent', () => {
      const name = service.resolveDisplayName({
        fullName: null,
        googleFullName: null,
        email: 'alex.smith@example.com',
      });
      expect(name).toBe('Alex Smith');
    });

    it('falls back to "there" when email local part cannot be cleaned', () => {
      const name = service.resolveDisplayName({
        fullName: '',
        googleFullName: '',
        email: '',
      });
      expect(name).toBe('there');
    });
  });

  describe('duplicate protection', () => {
    it('skips email when a welcome notification already exists for user', async () => {
      prismaService.notification.findFirst.mockResolvedValue({
        id: 'notif-123',
        createdAt: new Date(),
        type: 'WELCOME_EMAIL',
      });

      const result = await service.sendWelcomeEmail({
        userId: 'user-123',
        email: 'user@example.com',
        fullName: 'Test User',
      });

      expect(result).toEqual({ success: true, skipped: true });
      expect(prismaService.notification.findFirst).toHaveBeenCalledWith({
        where: { userId: 'user-123', type: 'WELCOME_EMAIL' },
      });
    });
  });

  describe('error resilience', () => {
    it('returns error without throwing unhandled exception if transporter sendMail fails', async () => {
      prismaService.notification.findFirst.mockResolvedValue(null);
      (service as any).transporter = {
        sendMail: jest.fn().mockRejectedValue(new Error('SMTP Network Timeout')),
      };

      const result = await service.sendWelcomeEmail({
        userId: 'user-456',
        email: 'user456@example.com',
      });

      expect(result.success).toBe(false);
      expect(result.error).toBe('SMTP Network Timeout');
    });
  });
});
