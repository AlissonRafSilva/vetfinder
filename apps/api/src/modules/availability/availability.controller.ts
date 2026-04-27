import { Body, Controller, Get, Put, Query, UseGuards } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { CurrentUser, type AuthenticatedUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { AvailabilityService } from './availability.service';
import { SearchAvailableProfessionalsDto } from './dto/search-available-professionals.dto';
import { ReplaceAvailabilityDto } from './dto/upsert-availability-slot.dto';

@Controller('availability')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AvailabilityController {
  constructor(private readonly availabilityService: AvailabilityService) {}

  @Roles(UserRole.VETERINARIAN, UserRole.INTERN)
  @Get('me')
  findMyAvailability(@CurrentUser() user: AuthenticatedUser) {
    return this.availabilityService.findMyAvailability(user);
  }

  @Roles(UserRole.VETERINARIAN, UserRole.INTERN)
  @Put('me')
  replaceMyAvailability(
    @Body() dto: ReplaceAvailabilityDto,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.availabilityService.replaceMyAvailability(dto, user);
  }

  @Roles(UserRole.CLINIC, UserRole.HOSPITAL)
  @Get('professionals')
  searchAvailableProfessionals(@Query() query: SearchAvailableProfessionalsDto) {
    return this.availabilityService.searchAvailableProfessionals(query);
  }
}
