import { Module } from '@nestjs/common';
import { FeesService } from './fees.service';
import { FeesController, PaymentsController, ReceiptsController } from './fees.controller';

@Module({
  providers: [FeesService],
  controllers: [FeesController, PaymentsController, ReceiptsController],
  exports: [FeesService],
})
export class FeesModule {}
