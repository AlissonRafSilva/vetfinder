import { Body, Controller, Delete, Get, Post, UseGuards } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import {
  CurrentUser,
  AuthenticatedUser,
} from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { AsaasAccountsService } from './asaas-accounts.service';
import { CreateAsaasAccountDto } from './dto/create-asaas-account.dto';

@Controller('payments/asaas/accounts')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.VETERINARIAN, UserRole.INTERN)
export class AsaasController {
  constructor(private readonly accountsService: AsaasAccountsService) {}

  @Post()
  create(
    @Body() dto: CreateAsaasAccountDto,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.accountsService.create(dto, user);
  }

  @Get('me')
  findMine(@CurrentUser() user: AuthenticatedUser) {
    return this.accountsService.findMine(user);
  }

  @Delete('me')
  resetMine(@CurrentUser() user: AuthenticatedUser) {
    return this.accountsService.resetMine(user);
  }
}
