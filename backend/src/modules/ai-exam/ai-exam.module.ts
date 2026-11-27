import { Module } from '@nestjs/common';
import { AdminAiExamController, AiEvaluationController, AiExamController, StudentAiExamController } from './ai-exam.controller';
import { AiExamAccessService } from './ai-exam-access.service';
import { AiExamTestsService } from './ai-exam-tests.service';
import { AiExamStudentService } from './ai-exam-student.service';
import { AiExamAnalyticsService } from './ai-exam-analytics.service';
import { AiEvaluationService } from './ai-evaluation.service';

/** AI Examination & Performance Analyzer (Classes 10-12). Self-contained; only registered in AppModule. */
@Module({
  providers: [AiExamAccessService, AiExamTestsService, AiExamStudentService, AiExamAnalyticsService, AiEvaluationService],
  controllers: [AiExamController, StudentAiExamController, AiEvaluationController, AdminAiExamController],
})
export class AiExamModule {}
