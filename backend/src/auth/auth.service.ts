import {
  ConflictException,
  Injectable,
  InternalServerErrorException,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import * as crypto from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService, AuditAction } from '../audit/audit.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { GoogleLoginDto } from './dto/google-login.dto';
import { MailService } from '../mail/mail.service';

const DEFAULT_CATEGORIES = [
  { name: 'Identity', icon: 'badge', color: '#3B82F6' },
  { name: 'Education', icon: 'school', color: '#10B981' },
  { name: 'Vehicle', icon: 'directions_car', color: '#F59E0B' },
  { name: 'Finance', icon: 'account_balance', color: '#8B5CF6' },
  { name: 'Medical', icon: 'medical_services', color: '#EF4444' },
  { name: 'Employment', icon: 'work', color: '#06B6D4' },
  { name: 'Property', icon: 'home', color: '#EC4899' },
  { name: 'Other', icon: 'folder', color: '#6B7280' },
];

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly auditService: AuditService,
    private readonly mailService: MailService,
  ) {}

  async register(dto: RegisterDto, ipAddress?: string, userAgent?: string) {
    const existing = await this.prisma.user.findUnique({
      where: { email: dto.email.toLowerCase().trim() },
    });

    if (existing) {
      throw new ConflictException('An account with this email address already exists');
    }

    const saltRounds = 12;
    const passwordHash = await bcrypt.hash(dto.password, saltRounds);

    const user = await this.prisma.$transaction(async (tx) => {
      const createdUser = await tx.user.create({
        data: {
          email: dto.email.toLowerCase().trim(),
          passwordHash,
          profile: {
            create: {
              fullName: dto.fullName || null,
            },
          },
          securitySettings: {
            create: {},
          },
        },
        include: {
          profile: true,
        },
      });

      // Seed default categories
      for (const cat of DEFAULT_CATEGORIES) {
        await tx.category.create({
          data: {
            userId: createdUser.id,
            name: cat.name,
            icon: cat.icon,
            color: cat.color,
            isSystem: true,
          },
        });
      }

      return createdUser;
    });

    const tokens = await this.generateTokens(user.id, user.email);

    await this.auditService.log({
      userId: user.id,
      action: AuditAction.LOGIN,
      ipAddress,
      userAgent,
      metadata: { method: 'registration' },
    });

    // Send welcome email to genuinely new registered user
    this.mailService
      .sendWelcomeEmail({
        userId: user.id,
        email: user.email,
        fullName: user.profile?.fullName,
      })
      .catch((err) => {
        this.logger.error(`Welcome email dispatch error: ${err?.message || err}`);
      });

    return {
      user: {
        id: user.id,
        email: user.email,
        fullName: user.profile?.fullName || null,
        createdAt: user.createdAt,
      },
      ...tokens,
    };
  }

  async login(dto: LoginDto, ipAddress?: string, userAgent?: string) {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email.toLowerCase().trim() },
      include: { profile: true },
    });

    if (!user || !user.isActive) {
      throw new UnauthorizedException('Invalid email or password');
    }

    const isPasswordValid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid email or password');
    }

    // Optional device registration
    if (dto.deviceId) {
      await this.prisma.device.upsert({
        where: {
          userId_deviceId: {
            userId: user.id,
            deviceId: dto.deviceId,
          },
        },
        update: {
          lastActiveAt: new Date(),
          deviceName: dto.deviceName || 'Mobile Device',
        },
        create: {
          userId: user.id,
          deviceId: dto.deviceId,
          deviceName: dto.deviceName || 'Mobile Device',
          platform: 'mobile',
        },
      });
    }

    const tokens = await this.generateTokens(user.id, user.email, dto.deviceId);

    await this.auditService.log({
      userId: user.id,
      action: AuditAction.LOGIN,
      ipAddress,
      userAgent,
      metadata: { method: 'password', deviceId: dto.deviceId },
    });

    return {
      user: {
        id: user.id,
        email: user.email,
        fullName: user.profile?.fullName || null,
        createdAt: user.createdAt,
      },
      ...tokens,
    };
  }

  async refresh(dto: RefreshTokenDto, ipAddress?: string, userAgent?: string) {
    let payload: any;
    try {
      const refreshSecret =
        this.configService.get<string>('JWT_REFRESH_SECRET') ||
        'dha_vault_refresh_secret_super_secure_key_2026_123456789';
      payload = this.jwtService.verify(dto.refreshToken, { secret: refreshSecret });
    } catch {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    const tokenHash = this.hashToken(dto.refreshToken);

    const storedToken = await this.prisma.refreshToken.findUnique({
      where: { tokenHash },
      include: { user: true },
    });

    if (!storedToken || storedToken.revokedAt || storedToken.expiresAt < new Date()) {
      // Possible token reuse attack detected! Revoke all tokens for this user if compromised
      if (storedToken && storedToken.revokedAt) {
        this.logger.warn(`Revoked refresh token reuse attempted for user ${storedToken.userId}`);
        await this.prisma.refreshToken.updateMany({
          where: { userId: storedToken.userId },
          data: { revokedAt: new Date() },
        });
      }
      throw new UnauthorizedException('Refresh token is invalid or has been revoked');
    }

    // Rotate token: revoke current token
    await this.prisma.refreshToken.update({
      where: { id: storedToken.id },
      data: { revokedAt: new Date() },
    });

    // Issue brand new token pair
    const tokens = await this.generateTokens(
      storedToken.userId,
      storedToken.user.email,
      storedToken.deviceId || undefined,
    );

    return tokens;
  }

  async logout(userId: string, refreshToken?: string, ipAddress?: string, userAgent?: string) {
    if (refreshToken) {
      const tokenHash = this.hashToken(refreshToken);
      await this.prisma.refreshToken.updateMany({
        where: { userId, tokenHash, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    } else {
      await this.prisma.refreshToken.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    }

    await this.auditService.log({
      userId,
      action: AuditAction.LOGOUT,
      ipAddress,
      userAgent,
    });

    return {
      success: true,
      message: 'Logged out successfully',
    };
  }

  async googleLogin(dto: GoogleLoginDto, ipAddress?: string, userAgent?: string) {
    let email = dto.email?.toLowerCase().trim();
    let fullName = dto.fullName?.trim();
    let avatarUrl = dto.avatarUrl;
    let googleId = dto.googleId;

    const isProduction = this.configService.get<string>('NODE_ENV') === 'production';
    if (isProduction && !dto.idToken) {
      throw new UnauthorizedException('Google ID token is required for authentication in production');
    }

    // Verify Google ID token directly with Google's tokeninfo endpoint
    if (dto.idToken) {
      try {
        const res = await fetch(`https://oauth2.googleapis.com/tokeninfo?id_token=${dto.idToken}`);
        if (!res.ok) {
          throw new UnauthorizedException('Invalid Google ID token');
        }
        const data = await res.json();
        const configuredClientId = this.configService.get<string>('GOOGLE_CLIENT_ID');
        const configuredAndroidClientId = this.configService.get<string>('GOOGLE_ANDROID_CLIENT_ID');
        if (configuredClientId && data.aud !== configuredClientId && data.aud !== configuredAndroidClientId) {
          this.logger.warn(`Google token aud mismatch: token aud is ${data.aud}, expected ${configuredClientId} or ${configuredAndroidClientId}`);
        }
        if (!data.email) {
          throw new UnauthorizedException('Google ID token does not contain a valid email address');
        }
        email = data.email.toLowerCase().trim();
        fullName = data.name || fullName;
        avatarUrl = data.picture || avatarUrl;
        googleId = data.sub || googleId;
      } catch (err: any) {
        this.logger.error(`Error verifying Google token: ${err.message}`);
        throw new UnauthorizedException(err.message || 'Failed to verify Google token');
      }
    }

    if (!email) {
      throw new UnauthorizedException('Google authentication failed: Email address is required');
    }

    // Check if user already exists
    let user = await this.prisma.user.findUnique({
      where: { email },
      include: { profile: true },
    });

    if (!user) {
      // Create new user account with secure random passwordHash
      const randomPassword = crypto.randomBytes(32).toString('hex');
      const passwordHash = await bcrypt.hash(randomPassword, 12);

      user = await this.prisma.$transaction(async (tx) => {
        const createdUser = await tx.user.create({
          data: {
            email,
            passwordHash,
            profile: {
              create: {
                fullName: fullName || email.split('@')[0],
                avatarUrl: avatarUrl || null,
              },
            },
            securitySettings: {
              create: {},
            },
          },
          include: {
            profile: true,
          },
        });

        // Seed default categories
        for (const cat of DEFAULT_CATEGORIES) {
          await tx.category.create({
            data: {
              userId: createdUser.id,
              name: cat.name,
              icon: cat.icon,
              color: cat.color,
              isSystem: true,
            },
          });
        }

        return createdUser;
      });

      this.logger.log('Google authentication successful.');
      this.logger.log('New user detected.');
      this.logger.log(`Welcome email queued for: ${user.email}`);

      // Dispatch welcome email ONLY for genuine new Google users
      this.mailService
        .sendWelcomeEmail({
          userId: user.id,
          email: user.email,
          fullName: user.profile?.fullName || fullName,
          googleFullName: fullName,
        })
        .catch((err) => {
          this.logger.error(`Google welcome email dispatch error: ${err?.message || err}`);
        });
    } else {
      this.logger.log(`Google authentication successful. Existing user: ${user.email}`);
      // Existing user: update avatar or name if available
      if (fullName || avatarUrl) {
        await this.prisma.profile.upsert({
          where: { userId: user.id },
          update: {
            fullName: fullName || user.profile?.fullName,
            avatarUrl: avatarUrl || user.profile?.avatarUrl,
          },
          create: {
            userId: user.id,
            fullName: fullName || email.split('@')[0],
            avatarUrl: avatarUrl || null,
          },
        });
      }
    }

    if (!user.isActive) {
      throw new UnauthorizedException('User account is deactivated');
    }

    // Optional device registration
    if (dto.deviceId) {
      await this.prisma.device.upsert({
        where: {
          userId_deviceId: {
            userId: user.id,
            deviceId: dto.deviceId,
          },
        },
        update: {
          lastActiveAt: new Date(),
          deviceName: dto.deviceName || 'Android Device',
        },
        create: {
          userId: user.id,
          deviceId: dto.deviceId,
          deviceName: dto.deviceName || 'Android Device',
          platform: 'mobile',
        },
      });
    }

    const tokens = await this.generateTokens(user.id, user.email, dto.deviceId);

    await this.auditService.log({
      userId: user.id,
      action: AuditAction.LOGIN,
      ipAddress,
      userAgent,
      metadata: { method: 'google_oauth', googleId },
    });

    return {
      user: {
        id: user.id,
        email: user.email,
        fullName: user.profile?.fullName || fullName || null,
        avatarUrl: user.profile?.avatarUrl || avatarUrl || null,
        createdAt: user.createdAt,
      },
      ...tokens,
    };
  }

  private async generateTokens(userId: string, email: string, deviceId?: string) {
    const accessSecret =
      this.configService.get<string>('JWT_ACCESS_SECRET') ||
      'dha_vault_access_secret_super_secure_key_2026_987654321';
    const refreshSecret =
      this.configService.get<string>('JWT_REFRESH_SECRET') ||
      'dha_vault_refresh_secret_super_secure_key_2026_123456789';

    const accessExpires = this.configService.get<string>('JWT_ACCESS_EXPIRES_IN', '15m');
    const refreshExpires = this.configService.get<string>('JWT_REFRESH_EXPIRES_IN', '7d');

    const [accessToken, refreshToken] = await Promise.all([
      this.jwtService.signAsync(
        { sub: userId, email, deviceId: deviceId || null },
        { secret: accessSecret, expiresIn: accessExpires },
      ),
      this.jwtService.signAsync(
        { sub: userId, email, jti: crypto.randomUUID() },
        { secret: refreshSecret, expiresIn: refreshExpires },
      ),
    ]);

    const tokenHash = this.hashToken(refreshToken);
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days

    await this.prisma.refreshToken.create({
      data: {
        userId,
        tokenHash,
        deviceId: deviceId || null,
        expiresAt,
      },
    });

    return {
      accessToken,
      refreshToken,
      tokenType: 'Bearer',
      expiresIn: 900, // 15 minutes in seconds
    };
  }

  private hashToken(token: string): string {
    return crypto.createHash('sha256').update(token).digest('hex');
  }
}
