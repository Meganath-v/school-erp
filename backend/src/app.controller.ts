import { Controller, Get } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';

@ApiTags('System')
@Controller()
export class AppController {
  @Get('health')
  @ApiOperation({ summary: 'Health check endpoint for Render and orchestrators' })
  healthCheck() {
    return {
      status: 'ok',
      service: 'ark-erp-backend',
      timestamp: new Date().toISOString(),
      uptime: Math.floor(process.uptime()),
    };
  }

  @Get('api/v1/health')
  @ApiOperation({ summary: 'API v1 health check alias' })
  apiHealthCheck() {
    return this.healthCheck();
  }
}

