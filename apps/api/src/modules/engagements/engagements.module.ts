import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';
import { PlatformConfigModule } from '../platform/platform-config.module';
import { EngagementsController } from './engagements.controller';
import { EngagementsService } from './engagements.service';

@Module({
  imports: [PlatformConfigModule, NotificationsModule],
  controllers: [EngagementsController],
  providers: [EngagementsService],
})
export class EngagementsModule {}
