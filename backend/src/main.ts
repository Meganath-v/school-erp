import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

// Support BigInt serialization in JSON (e.g. Prisma BigInt fields)
(BigInt.prototype as any).toJSON = function () {
  return Number(this);
};
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

  // Set global API prefix (excluding health checks and root)
  app.setGlobalPrefix('api/v1', {
    exclude: ['health', ''],
  });

  // Enable CORS (bearer-token based authentication without cookies)
  const isProduction = process.env.NODE_ENV === 'production';
  const rawCors = (process.env.CORS_ORIGIN || '').trim();
  const allowedOrigins = rawCors.split(',').map((o) => o.trim()).filter(Boolean);

  app.enableCors({
    origin: (origin, callback) => {
      // Allow requests with no origin (mobile apps, server-to-server, curl)
      if (!origin) return callback(null, true);
      if (allowedOrigins.length === 0 || allowedOrigins.includes('*') || !isProduction) {
        return callback(null, true);
      }
      if (allowedOrigins.includes(origin) || origin.endsWith('.onrender.com')) {
        return callback(null, true);
      }
      return callback(null, true);
    },
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
    .setTitle('Ark-ERP Multi-Tenant Institutional Platform API')
    .setDescription(
      'Complete production API documentation for Ark-ERP Multi-Tenant Academic Management System (AMS / LMS / ERP)',
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
  await app.listen(port, '0.0.0.0');
  console.log(`🚀 Ark-ERP API running at: http://localhost:${port}/api/v1`);
  if (swaggerEnabled) {
    console.log(`📑 OpenAPI Documentation available at: http://localhost:${port}/api/docs`);
  }
  console.log(`🖥️  Teacher Desktop Webpage available at: http://localhost:${port}/teacher/index.html`);
}

bootstrap();
