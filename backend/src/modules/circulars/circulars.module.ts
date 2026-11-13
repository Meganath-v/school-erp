import { Module } from '@nestjs/common';
import { CircularsService } from './circulars.service';
import { CircularsController } from './circulars.controller';
import { PrismaModule } from '../../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [CircularsController],
  providers: [CircularsService],
  exports: [CircularsService],
})
export class CircularsModule {}

