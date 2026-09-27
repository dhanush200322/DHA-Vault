import { Body, Controller, Delete, Get, Param, Post } from '@nestjs/common';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { TagsService } from './tags.service';

@Controller('tags')
export class TagsController {
  constructor(private readonly tagsService: TagsService) {}

  @Get()
  async findAll(@CurrentUser('userId') userId: string) {
    return this.tagsService.findAll(userId);
  }

  @Post()
  async create(
    @CurrentUser('userId') userId: string,
    @Body('name') name: string,
    @Body('color') color?: string,
  ) {
    return this.tagsService.create(userId, name, color);
  }

  @Delete(':id')
  async delete(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
  ) {
    return this.tagsService.delete(userId, id);
  }
}
