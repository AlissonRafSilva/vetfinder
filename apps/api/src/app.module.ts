import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './common/database/prisma.module';
import { StorageModule } from './common/storage/storage.module';
import { AdminModule } from './modules/admin/admin.module';
import { ApplicationsModule } from './modules/applications/applications.module';
import { AuthModule } from './modules/auth/auth.module';
import { AvailabilityModule } from './modules/availability/availability.module';
import { DocumentsModule } from './modules/documents/documents.module';
import { EngagementsModule } from './modules/engagements/engagements.module';
import { HealthModule } from './modules/health/health.module';
import { InstitutionsModule } from './modules/institutions/institutions.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { OpportunitiesModule } from './modules/opportunities/opportunities.module';
import { PaymentsModule } from './modules/payments/payments.module';
import { PlatformConfigModule } from './modules/platform/platform-config.module';
import { ProfessionalsModule } from './modules/professionals/professionals.module';
import { UsersModule } from './modules/users/users.module';
import { SpecialtiesModule } from './modules/specialties/specialties.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
    }),
    PrismaModule,
    StorageModule,
    HealthModule,
    AuthModule,
    UsersModule,
    SpecialtiesModule,
    ProfessionalsModule,
    InstitutionsModule,
    DocumentsModule,
    AvailabilityModule,
    OpportunitiesModule,
    ApplicationsModule,
    EngagementsModule,
    PaymentsModule,
    PlatformConfigModule,
    NotificationsModule,
    AdminModule,
  ],
})
export class AppModule {}
