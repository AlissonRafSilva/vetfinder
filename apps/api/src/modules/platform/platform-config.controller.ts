import { Controller, Get } from '@nestjs/common';
import { PlatformConfigService } from './platform-config.service';

@Controller('platform')
export class PlatformConfigController {
  constructor(private readonly platformConfigService: PlatformConfigService) {}

  @Get('config')
  getConfig() {
    return this.platformConfigService.getConfig();
  }
}
