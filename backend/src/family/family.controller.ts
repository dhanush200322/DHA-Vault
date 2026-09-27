import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Req,
} from '@nestjs/common';
import { Request } from 'express';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { FamilyService } from './family.service';
import { CreateFamilyDto } from './dto/create-family.dto';
import { UpdateFamilyDto } from './dto/update-family.dto';
import { InviteMemberDto } from './dto/invite-member.dto';
import { UpdateRoleDto } from './dto/update-role.dto';
import { ShareFamilyDocDto } from './dto/share-family-doc.dto';

@Controller('families')
export class FamilyController {
  constructor(private readonly familyService: FamilyService) {}

  @Post()
  async create(
    @CurrentUser('userId') userId: string,
    @Body() dto: CreateFamilyDto,
    @Req() req: Request,
  ) {
    const ip = (req.headers['x-forwarded-for'] as string) || req.ip;
    const ua = req.headers['user-agent'];
    return this.familyService.create(userId, dto, ip, ua);
  }

  @Get()
  async findAll(@CurrentUser('userId') userId: string) {
    return this.familyService.findAll(userId);
  }

  // Invitation acceptance endpoint (placed before :familyId to prevent param clash)
  @Post('invitations/:token/accept')
  @HttpCode(HttpStatus.OK)
  async acceptInvitation(
    @CurrentUser('userId') userId: string,
    @Param('token') token: string,
    @Req() req: Request,
  ) {
    const ip = (req.headers['x-forwarded-for'] as string) || req.ip;
    const ua = req.headers['user-agent'];
    return this.familyService.acceptInvitation(userId, token, ip, ua);
  }

  @Get(':familyId')
  async findOne(
    @CurrentUser('userId') userId: string,
    @Param('familyId') familyId: string,
  ) {
    return this.familyService.findOne(userId, familyId);
  }

  @Patch(':familyId')
  async update(
    @CurrentUser('userId') userId: string,
    @Param('familyId') familyId: string,
    @Body() dto: UpdateFamilyDto,
    @Req() req: Request,
  ) {
    const ip = (req.headers['x-forwarded-for'] as string) || req.ip;
    const ua = req.headers['user-agent'];
    return this.familyService.update(userId, familyId, dto, ip, ua);
  }

  @Delete(':familyId')
  async delete(
    @CurrentUser('userId') userId: string,
    @Param('familyId') familyId: string,
    @Req() req: Request,
  ) {
    const ip = (req.headers['x-forwarded-for'] as string) || req.ip;
    const ua = req.headers['user-agent'];
    return this.familyService.delete(userId, familyId, ip, ua);
  }

  @Get(':familyId/members')
  async getMembers(
    @CurrentUser('userId') userId: string,
    @Param('familyId') familyId: string,
  ) {
    return this.familyService.getMembers(userId, familyId);
  }

  @Post(':familyId/invitations')
  async createInvitation(
    @CurrentUser('userId') userId: string,
    @Param('familyId') familyId: string,
    @Body() dto: InviteMemberDto,
    @Req() req: Request,
  ) {
    const ip = (req.headers['x-forwarded-for'] as string) || req.ip;
    const ua = req.headers['user-agent'];
    return this.familyService.createInvitation(userId, familyId, dto, ip, ua);
  }

  @Patch(':familyId/members/:memberUserId/role')
  async updateMemberRole(
    @CurrentUser('userId') userId: string,
    @Param('familyId') familyId: string,
    @Param('memberUserId') memberUserId: string,
    @Body() dto: UpdateRoleDto,
    @Req() req: Request,
  ) {
    const ip = (req.headers['x-forwarded-for'] as string) || req.ip;
    const ua = req.headers['user-agent'];
    return this.familyService.updateMemberRole(userId, familyId, memberUserId, dto, ip, ua);
  }

  @Delete(':familyId/members/:memberUserId')
  async removeMember(
    @CurrentUser('userId') userId: string,
    @Param('familyId') familyId: string,
    @Param('memberUserId') memberUserId: string,
    @Req() req: Request,
  ) {
    const ip = (req.headers['x-forwarded-for'] as string) || req.ip;
    const ua = req.headers['user-agent'];
    return this.familyService.removeMember(userId, familyId, memberUserId, ip, ua);
  }

  @Get(':familyId/documents')
  async getDocuments(
    @CurrentUser('userId') userId: string,
    @Param('familyId') familyId: string,
  ) {
    return this.familyService.getDocuments(userId, familyId);
  }

  @Post(':familyId/documents/:documentId/share')
  async shareDocument(
    @CurrentUser('userId') userId: string,
    @Param('familyId') familyId: string,
    @Param('documentId') documentId: string,
    @Body() dto: ShareFamilyDocDto,
    @Req() req: Request,
  ) {
    const ip = (req.headers['x-forwarded-for'] as string) || req.ip;
    const ua = req.headers['user-agent'];
    return this.familyService.shareDocument(userId, familyId, documentId, dto, ip, ua);
  }

  @Delete(':familyId/documents/:documentId/access/:accessUserId')
  async revokeDocumentAccess(
    @CurrentUser('userId') userId: string,
    @Param('familyId') familyId: string,
    @Param('documentId') documentId: string,
    @Param('accessUserId') accessUserId: string,
    @Req() req: Request,
  ) {
    const ip = (req.headers['x-forwarded-for'] as string) || req.ip;
    const ua = req.headers['user-agent'];
    return this.familyService.revokeDocumentAccess(userId, familyId, documentId, accessUserId, ip, ua);
  }
}
