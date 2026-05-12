import { Body, Controller, Get, Param, Patch, Query, UseGuards } from '@nestjs/common';
import { UserRole, VerificationStatus } from '@prisma/client';
import { CurrentUser, type AuthenticatedUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { ReviewDocumentDto } from '../documents/dto/review-document.dto';
import { AdminService } from './admin.service';

@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get('summary')
  summary() {
    return this.adminService.summary();
  }

  @Get('documents')
  documents(@Query('status') status?: VerificationStatus) {
    return this.adminService.listDocuments(status);
  }

  @Patch('documents/:id/review')
  reviewDocument(
    @Param('id') id: string,
    @Body() dto: ReviewDocumentDto,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.adminService.reviewDocument(id, dto, user);
  }
}
