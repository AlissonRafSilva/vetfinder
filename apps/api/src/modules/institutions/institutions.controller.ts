import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { CurrentUser, type AuthenticatedUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
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

  @Get(':id')
  findById(@Param('id') id: string) {
    return this.institutionsService.findById(id);
  }
}
