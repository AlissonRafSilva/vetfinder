import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { CurrentUser, type AuthenticatedUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { CreateEngagementDto } from './dto/create-engagement.dto';
import { EngagementsService } from './engagements.service';

@Controller('engagements')
@UseGuards(JwtAuthGuard, RolesGuard)
export class EngagementsController {
  constructor(private readonly engagementsService: EngagementsService) {}

  @Roles(UserRole.CLINIC, UserRole.HOSPITAL)
  @Post()
  create(@Body() dto: CreateEngagementDto, @CurrentUser() user: AuthenticatedUser) {
    return this.engagementsService.create(dto, user);
  }

  @Roles(UserRole.CLINIC, UserRole.HOSPITAL)
  @Get('me')
  findMine(@CurrentUser() user: AuthenticatedUser) {
    return this.engagementsService.findForInstitution(user);
  }

  @Roles(UserRole.VETERINARIAN, UserRole.INTERN)
  @Get('professional/me')
  findMineAsProfessional(@CurrentUser() user: AuthenticatedUser) {
    return this.engagementsService.findForProfessional(user);
  }

  @Get(':id')
  findOne(@Param('id') id: string, @CurrentUser() user: AuthenticatedUser) {
    return this.engagementsService.findOne(id, user);
  }
}
