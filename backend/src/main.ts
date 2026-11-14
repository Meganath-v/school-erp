import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { NestExpressApplication } from '@nestjs/platform-express';
import helmet from 'helmet';
import * as compression from 'compression';
import { join } from 'path';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  // Behind nginx: use X-Forwarded-For for the client IP (rate limiting)
  app.set('trust proxy', 1);

  // Serve static assets (Teacher desktop portal, uploads, assets)
  app.useStaticAssets(join(process.cwd(), 'public'));

  // Security headers with Helmet
  app.use(
    helmet({
      crossOriginResourcePolicy: false,
      contentSecurityPolicy: false, // Allow Swagger & client rendering
    }),
  );

  // Gzip compression
  app.use(compression());

  // Global exception filter conforming to Section 11.1
  app.useGlobalFilters(new AllExceptionsFilter());

  // Set global API prefix
  app.setGlobalPrefix('api/v1');

  // Enable CORS only for configured origins. Auth uses bearer tokens, not cookies,
  // so credentials are never needed and a wildcard origin is refused in production.
  const isProduction = process.env.NODE_ENV === 'production';
  const allowedOrigins = (process.env.CORS_ORIGIN || '')
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);
  if (isProduction && (allowedOrigins.length === 0 || allowedOrigins.includes('*'))) {
    throw new Error('Set CORS_ORIGIN to an explicit, comma-separated list of origins in production.');
  }
  app.enableCors({
    origin: allowedOrigins.length > 0 && !allowedOrigins.includes('*') ? allowedOrigins : true,
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
    credentials: false,
  });

  // Global validation pipe
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidUnknownValues: false,
    }),
  );

  // Swagger OpenAPI Documentation
  const config = new DocumentBuilder()
    .setTitle('Linways-Grade Multi-Tenant School & Campus ERP API')
    .setDescription(
      'Complete production API documentation for Multi-Tenant School & Institutional Academic Management System (AMS / LMS / ERP)',
    )
    .setVersion('2.0')
    .addBearerAuth()
    .build();

  // API docs are only exposed outside production unless explicitly enabled.
  const swaggerEnabled = !isProduction || process.env.ENABLE_SWAGGER === 'true';
  if (swaggerEnabled) {
    const document = SwaggerModule.createDocument(app, config);
    SwaggerModule.setup('api/docs', app, document);
  }

  const port = process.env.PORT || 3000;
  await app.listen(port);
  console.log(`🚀 Linways-Grade ERP API running at: http://localhost:${port}/api/v1`);
  if (swaggerEnabled) {
    console.log(`📑 OpenAPI Documentation available at: http://localhost:${port}/api/docs`);
  }
  console.log(`🖥️  Teacher Desktop Webpage available at: http://localhost:${port}/teacher/index.html`);
}

bootstrap();
