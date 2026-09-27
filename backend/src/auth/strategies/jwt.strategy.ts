import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { PrismaService } from '../../prisma/prisma.service';

export interface JwtPayload {
  sub: string;
  email: string;
  deviceId?: string | null;
  iat?: number;
  exp?: number;
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(
    configService: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    const secret =
      configService.get<string>('JWT_ACCESS_SECRET') ||
      'dha_vault_access_secret_super_secure_key_2026_987654321';
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: secret,
    });
  }

  async validate(payload: JwtPayload) {
    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      select: { id: true, email: true, isActive: true },
    });

    if (!user || !user.isActive) {
      throw new UnauthorizedException('User account is inactive or not found');
    }

    if (payload.deviceId) {
      const device = await this.prisma.device.findUnique({
        where: { userId_deviceId: { userId: user.id, deviceId: payload.deviceId } },
      });

      if (!device) {
        throw new UnauthorizedException('Device access revoked. Please re-authenticate.');
      }

      if (device.isLocked) {
        throw new UnauthorizedException('Device is remotely locked by vault owner');
      }

      // Update lastActiveAt non-blockingly
      this.prisma.device
        .update({
          where: { id: device.id },
          data: { lastActiveAt: new Date() },
        })
        .catch(() => {});
    }

    return {
      userId: user.id,
      email: user.email,
      deviceId: payload.deviceId,
    };
  }
}
