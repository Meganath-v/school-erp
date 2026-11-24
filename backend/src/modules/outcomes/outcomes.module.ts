import { Module } from '@nestjs/common';
import { OutcomesController } from './outcomes.controller';
import { OutcomesService } from './outcomes.service';

@Module({
  providers: [OutcomesService],
  controllers: [OutcomesController],
  exports: [OutcomesService],
})
export class OutcomesModule {}
