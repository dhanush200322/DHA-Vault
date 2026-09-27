import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
} from '@nestjs/common';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { RemindersService, CreateCustomReminderDto } from './reminders.service';

@Controller()
export class RemindersController {
  constructor(private readonly remindersService: RemindersService) {}

  @Post('reminders/check')
  @HttpCode(HttpStatus.OK)
  async checkReminders() {
    return this.remindersService.checkAndTriggerReminders();
  }

  @Get('documents/:id/reminders')
  async getReminders(
    @CurrentUser('userId') userId: string,
    @Param('id') documentId: string,
  ) {
    return this.remindersService.getRemindersForDocument(userId, documentId);
  }

  @Post('documents/:id/reminders')
  @HttpCode(HttpStatus.CREATED)
  async addReminder(
    @CurrentUser('userId') userId: string,
    @Param('id') documentId: string,
    @Body() dto: CreateCustomReminderDto,
  ) {
    return this.remindersService.addCustomReminder(userId, documentId, dto);
  }

  @Delete('documents/:id/reminders/:reminderId')
  async deleteReminder(
    @CurrentUser('userId') userId: string,
    @Param('reminderId') reminderId: string,
  ) {
    return this.remindersService.deleteReminder(userId, reminderId);
  }
}
