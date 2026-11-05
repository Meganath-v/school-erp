import { Module } from '@nestjs/common';
import { TenantDiscoveryController } from './tenant-discovery.controller';

@Module({
  controllers: [TenantDiscoveryController],
})
export class TenantDiscoveryModule {}
