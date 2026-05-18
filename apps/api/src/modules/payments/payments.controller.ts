import { Body, Controller, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { CurrentUser, type AuthenticatedUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { CreatePaymentDto } from './dto/create-payment.dto';
import { PaymentsService } from './payments.service';

@Controller('payments')
@UseGuards(JwtAuthGuard, RolesGuard)
export class PaymentsController {
  constructor(private readonly paymentsService: PaymentsService) {}

  @Roles(UserRole.CLINIC, UserRole.HOSPITAL)
  @Post()
  create(@Body() dto: CreatePaymentDto, @CurrentUser() user: AuthenticatedUser) {
    return this.paymentsService.create(dto, user);
  }

  @Get('engagement/:engagementId')
  findByEngagement(
    @Param('engagementId') engagementId: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.paymentsService.findByEngagement(engagementId, user);
  }

  @Get(':id')
  findOne(@Param('id') id: string, @CurrentUser() user: AuthenticatedUser) {
    return this.paymentsService.findOne(id, user);
  }

  @Roles(UserRole.CLINIC, UserRole.HOSPITAL)
  @Patch(':id/confirm-sandbox')
  confirmSandbox(@Param('id') id: string, @CurrentUser() user: AuthenticatedUser) {
    return this.paymentsService.confirmSandboxPayment(id, user);
  }
}
