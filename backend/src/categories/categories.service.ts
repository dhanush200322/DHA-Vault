import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateCategoryDto } from './dto/create-category.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';

@Injectable()
export class CategoriesService {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(userId: string) {
    return this.prisma.category.findMany({
      where: { userId },
      include: {
        _count: {
          select: { documents: true },
        },
      },
      orderBy: [{ isSystem: 'desc' }, { name: 'asc' }],
    });
  }

  async findOne(userId: string, id: string) {
    const category = await this.prisma.category.findUnique({
      where: { id },
      include: {
        _count: {
          select: { documents: true },
        },
      },
    });

    if (!category) {
      throw new NotFoundException('Category not found');
    }

    if (category.userId !== userId) {
      throw new ForbiddenException('You do not have access to this category');
    }

    return category;
  }

  async create(userId: string, dto: CreateCategoryDto) {
    const existing = await this.prisma.category.findUnique({
      where: {
        userId_name: {
          userId,
          name: dto.name.trim(),
        },
      },
    });

    if (existing) {
      throw new ConflictException('A category with this name already exists');
    }

    return this.prisma.category.create({
      data: {
        userId,
        name: dto.name.trim(),
        icon: dto.icon || 'folder',
        color: dto.color || '#3B82F6',
      },
    });
  }

  async update(userId: string, id: string, dto: UpdateCategoryDto) {
    const category = await this.findOne(userId, id);

    if (dto.name && dto.name.trim() !== category.name) {
      const existing = await this.prisma.category.findUnique({
        where: {
          userId_name: {
            userId,
            name: dto.name.trim(),
          },
        },
      });

      if (existing && existing.id !== id) {
        throw new ConflictException('Another category with this name already exists');
      }
    }

    return this.prisma.category.update({
      where: { id },
      data: {
        ...(dto.name && { name: dto.name.trim() }),
        ...(dto.icon !== undefined && { icon: dto.icon }),
        ...(dto.color !== undefined && { color: dto.color }),
      },
    });
  }

  async delete(userId: string, id: string) {
    await this.findOne(userId, id);

    return this.prisma.category.delete({
      where: { id },
    });
  }
}
