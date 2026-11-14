import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsIn, IsNotEmpty, IsOptional, IsString, IsBoolean } from 'class-validator';

export const REMINDER_CATEGORIES = [
  'FEE_DUE',
  'ATTENDANCE_LOW',
  'EXAM_MARK_ENTRY',
  'LEAVE_APPROVAL',
  'ASSIGNMENT_DEADLINE',
  'CIRCULAR_ACK',
  'TASK_DUE',
  'CUSTOM',
] as const;

export const REMINDER_PRIORITIES = ['LOW', 'MEDIUM', 'HIGH', 'URGENT'] as const;

export class CreateReminderDto {
  @ApiProperty({ example: 'Submit Term 1 Marks Broadsheet', description: 'Reminder title' })
  @IsNotEmpty()
  @IsString()
  title: string;

  @ApiPropertyOptional({ example: 'Complete grade moderation for Grade 10 Mathematics' })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional({ example: 'CUSTOM', enum: REMINDER_CATEGORIES })
  @IsOptional()
  @IsIn(REMINDER_CATEGORIES)
  category?: string;

  @ApiPropertyOptional({ example: 'HIGH', enum: REMINDER_PRIORITIES })
  @IsOptional()
  @IsIn(REMINDER_PRIORITIES)
  priority?: string;

  @ApiPropertyOptional({ example: '2026-11-25T17:00:00.000Z' })
  @IsOptional()
  @IsDateString()
  dueDate?: string;

  @ApiPropertyOptional({ example: '2026-11-25T09:00:00.000Z' })
  @IsOptional()
  @IsDateString()
  remindAt?: string;

  @ApiPropertyOptional({ example: 'ExamSubject' })
  @IsOptional()
  @IsString()
  entityType?: string;

  @ApiPropertyOptional({ example: 'exam-uuid-1' })
  @IsOptional()
  @IsString()
  entityId?: string;
}

export class UpdateReminderStatusDto {
  @ApiProperty({ example: 'COMPLETED', enum: ['PENDING', 'SENT', 'DISMISSED', 'COMPLETED'] })
  @IsIn(['PENDING', 'SENT', 'DISMISSED', 'COMPLETED'])
  status: string;
}

export class TriggerWorkflowDto {
  @ApiPropertyOptional({ example: false, description: 'Force re-evaluation of non-expired alerts' })
  @IsOptional()
  @IsBoolean()
  force?: boolean;
}
