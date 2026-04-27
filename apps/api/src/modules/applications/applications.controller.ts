import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { CurrentUser, type AuthenticatedUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { ApplyOpportunityDto } from './dto/apply-opportunity.dto';
import { InviteProfessionalDto } from './dto/invite-professional.dto';
import { RespondApplicationDto } from './dto/respond-application.dto';
import { RespondInviteDto } from './dto/respond-invite.dto';
import { ApplicationsService } from './applications.service';

@Controller('applications')
@UseGuards(JwtAuthGuard, RolesGuard)
export class ApplicationsController {
  constructor(private readonly applicationsService: ApplicationsService) {}

  @Roles(UserRole.VETERINARIAN, UserRole.INTERN)
  @Post('opportunities/:opportunityId/apply')
  apply(
    @Param('opportunityId') opportunityId: string,
    @Body() dto: ApplyOpportunityDto,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.applicationsService.apply(opportunityId, dto, user);
  }

  @Roles(UserRole.CLINIC, UserRole.HOSPITAL)
  @Post('opportunities/:opportunityId/invite')
  invite(
    @Param('opportunityId') opportunityId: string,
    @Body() dto: InviteProfessionalDto,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.applicationsService.invite(opportunityId, dto, user);
  }

  @Roles(UserRole.VETERINARIAN, UserRole.INTERN)
  @Get('me')
  myApplications(@CurrentUser() user: AuthenticatedUser) {
    return this.applicationsService.findForProfessional(user.userId);
  }

  @Roles(UserRole.VETERINARIAN, UserRole.INTERN)
  @Get('invites/me')
  myInvites(@CurrentUser() user: AuthenticatedUser) {
    return this.applicationsService.findInvitesForProfessional(user.userId);
  }

  @Roles(UserRole.CLINIC, UserRole.HOSPITAL)
  @Get('opportunities/:opportunityId')
  findByOpportunity(
    @Param('opportunityId') opportunityId: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.applicationsService.findByOpportunity(opportunityId, user);
  }

  @Roles(UserRole.CLINIC, UserRole.HOSPITAL)
  @Get('opportunities/:opportunityId/invites')
  findInvitesByOpportunity(
    @Param('opportunityId') opportunityId: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.applicationsService.findInvitesByOpportunity(opportunityId, user);
  }

  @Roles(UserRole.CLINIC, UserRole.HOSPITAL)
  @Post(':applicationId/respond')
  respondApplication(
    @Param('applicationId') applicationId: string,
    @Body() dto: RespondApplicationDto,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.applicationsService.respondApplication(applicationId, dto, user);
  }

  @Roles(UserRole.VETERINARIAN, UserRole.INTERN)
  @Post('invites/:inviteId/respond')
  respondInvite(
    @Param('inviteId') inviteId: string,
    @Body() dto: RespondInviteDto,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.applicationsService.respondInvite(inviteId, dto, user);
  }
}
