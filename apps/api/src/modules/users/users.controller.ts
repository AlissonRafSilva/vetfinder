import { Body, Controller, Delete, Get, UseGuards } from '@nestjs/common';
import { CurrentUser, type AuthenticatedUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { DeactivateAccountDto } from './dto/deactivate-account.dto';
import { UsersService } from './users.service';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @UseGuards(JwtAuthGuard)
  @Get('me')
  me(@CurrentUser() user: AuthenticatedUser) {
    return this.usersService.findById(user.userId);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me/export')
  exportMine(@CurrentUser() user: AuthenticatedUser) {
    return this.usersService.exportMyData(user.userId);
  }

  @UseGuards(JwtAuthGuard)
  @Delete('me')
  deactivateMine(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: DeactivateAccountDto,
  ) {
    return this.usersService.deactivateMyAccount(user.userId, dto.confirmation);
  }

}
