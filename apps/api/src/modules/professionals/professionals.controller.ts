import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { CurrentUser, type AuthenticatedUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateInternProfileDto } from './dto/create-intern-profile.dto';
import { CreateVeterinarianProfileDto } from './dto/create-veterinarian-profile.dto';
import { ProfessionalsService } from './professionals.service';

@Controller('professionals')
export class ProfessionalsController {
  constructor(private readonly professionalsService: ProfessionalsService) {}

  @UseGuards(JwtAuthGuard)
  @Post('veterinarians')
  createVeterinarianProfile(
    @Body() dto: CreateVeterinarianProfileDto,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.professionalsService.createVeterinarianProfile(dto, user);
  }

  @UseGuards(JwtAuthGuard)
  @Post('interns')
  createInternProfile(
    @Body() dto: CreateInternProfileDto,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.professionalsService.createInternProfile(dto, user);
  }

  @Get(':userId')
  findProfessionalProfile(@Param('userId') userId: string) {
    return this.professionalsService.findByUserId(userId);
  }
}
