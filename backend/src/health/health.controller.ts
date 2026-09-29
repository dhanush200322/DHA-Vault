import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Public } from '../common/decorators/public.decorator';

@Controller('health')
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

  @Public()
  @Get()
  async getHealth() {
    const isDbConnected = await this.prisma.isHealthy();

    if (!isDbConnected) {
      throw new ServiceUnavailableException({
        status: 'error',
        service: 'DHA Vault API',
        database: 'disconnected',
      });
    }

    return {
      status: 'ok',
      service: 'DHA Vault API',
      database: 'connected',
    };
  }

  @Public()
  @Get('storage')
  getStorageHealth() {
    return {
      status: 'ok',
      storageMode: 'Local / Zero-Cost',
      provider: 'local',
      encrypted: true,
      cloudBackup: 'disabled',
    };
  }
}
