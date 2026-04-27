import { Body, Controller, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { OpportunityStatus, UserRole } from '@prisma/client';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { OpportunitiesService } from './opportunities.service';
import { CreateOpportunityDto } from './dto/create-opportunity.dto';
import { ListOpportunitiesDto } from './dto/list-opportunities.dto';
import { UpdateOpportunityDto } from './dto/update-opportunity.dto';
import { UpdateOpportunityStatusDto } from './dto/update-opportunity-status.dto';

@Controller('opportunities')
export class OpportunitiesController {
  constructor(private readonly opportunitiesService: OpportunitiesService) {}

  @Get()
  findAll(@Query() query: ListOpportunitiesDto) {
    return this.opportunitiesService.findAll(query);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.CLINIC, UserRole.HOSPITAL)
  @Get('me')
  findMine(@CurrentUser() user: { userId: string; role: UserRole; email: string; status: string }) {
    return this.opportunitiesService.findMine(user);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.opportunitiesService.findOne(id);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.CLINIC, UserRole.HOSPITAL)
  @Post()
  create(
    @Body() dto: CreateOpportunityDto,
    @CurrentUser() user: { userId: string },
  ) {
    return this.opportunitiesService.create(dto, user.userId);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.CLINIC, UserRole.HOSPITAL)
  @Patch(':id/status')
  updateStatus(
    @Param('id') id: string,
    @Body() dto: UpdateOpportunityStatusDto,
    @CurrentUser() user: { userId: string; role: UserRole; email: string; status: string },
  ) {
    return this.opportunitiesService.updateStatus(id, dto.status, user);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.CLINIC, UserRole.HOSPITAL)
  @Patch(':id')
  update(
    @Param('id') id: string,
    @Body() dto: UpdateOpportunityDto,
    @CurrentUser() user: { userId: string; role: UserRole; email: string; status: string },
  ) {
    return this.opportunitiesService.update(id, dto, user);
  }
}
