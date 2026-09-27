import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class TagsService {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(userId: string) {
    return this.prisma.tag.findMany({
      where: { userId },
      orderBy: { name: 'asc' },
    });
  }

  async create(userId: string, name: string, color?: string) {
    const existing = await this.prisma.tag.findUnique({
      where: { userId_name: { userId, name: name.trim() } },
    });

    if (existing) {
      throw new ConflictException('Tag already exists');
    }

    return this.prisma.tag.create({
      data: {
        userId,
        name: name.trim(),
        color: color || '#10B981',
      },
    });
  }

  async delete(userId: string, id: string) {
    const tag = await this.prisma.tag.findUnique({ where: { id } });
    if (!tag || tag.userId !== userId) {
      throw new NotFoundException('Tag not found');
    }

    return this.prisma.tag.delete({ where: { id } });
  }
}
