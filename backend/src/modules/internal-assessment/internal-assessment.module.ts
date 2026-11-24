import { Module } from '@nestjs/common';
import { InternalAssessmentController, QuizzesController } from './internal-assessment.controller';
import { InternalAssessmentService } from './internal-assessment.service';
import { QuizzesService } from './quizzes.service';

@Module({
  providers: [InternalAssessmentService, QuizzesService],
  controllers: [InternalAssessmentController, QuizzesController],
})
export class InternalAssessmentModule {}
