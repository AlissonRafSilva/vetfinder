import { Module } from '@nestjs/common';
import { PlatformConfigModule } from '../platform/platform-config.module';
import { EngagementsController } from './engagements.controller';
import { EngagementsService } from './engagements.service';

@Module({
  imports: [PlatformConfigModule],
  controllers: [EngagementsController],
  providers: [EngagementsService],
})
export class EngagementsModule {}
