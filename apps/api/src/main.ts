import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { buildCorsOrigin } from './common/security/cors-options';
import { assertSafeRuntimeConfig } from './common/security/env-security';
import { securityHeadersMiddleware } from './common/security/security-headers.middleware';
import { AppModule } from './app.module';

async function bootstrap() {
  assertSafeRuntimeConfig();

  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  app.use(securityHeadersMiddleware);

  app.enableCors({
    origin: buildCorsOrigin(),
    credentials: true,
  });

  app.setGlobalPrefix('v1');
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      forbidUnknownValues: true,
      transform: true,
      transformOptions: {
        enableImplicitConversion: false,
      },
    }),
  );

  const port = Number(process.env.PORT ?? 3000);
  await app.listen(port);
}

void bootstrap();
