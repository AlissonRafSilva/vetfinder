import { Body, Controller, Get, Patch, Post, UseGuards } from '@nestjs/common';
import { CurrentUser, type AuthenticatedUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { UpdateProfileAddressDto } from '../../common/dto/update-profile-address.dto';
import { CreateInstitutionDto } from './dto/create-institution.dto';
import { InstitutionsService } from './institutions.service';

@Controller('institutions')
export class InstitutionsController {
  constructor(private readonly institutionsService: InstitutionsService) {}

  @UseGuards(JwtAuthGuard)
  @Post()
  create(
    @Body() dto: CreateInstitutionDto,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.institutionsService.create(dto, user);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  findMine(@CurrentUser() user: AuthenticatedUser) {
    return this.institutionsService.findMine(user);
  }

  @UseGuards(JwtAuthGuard)
  @Patch('me/address')
  updateMyAddress(
    @Body() dto: UpdateProfileAddressDto,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.institutionsService.updateMyAddress(dto, user);
  }

}
