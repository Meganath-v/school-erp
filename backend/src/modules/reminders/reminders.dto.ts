import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsIn, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateReminderDto {
  @ApiProperty({ example: 'Submit Term 1 Marks Broadsheet', description: 'Reminder title' })
  @IsNotEmpty()
  @IsString()
  title: string;

  @ApiPropertyOptional({ example: 'Complete grade moderation for Grade 10 Mathematics' })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional({ example: 'CUSTOM', enum: ['FEE_DUE', 'ATTENDANCE_ALERT', 'EXAM_UPCOMING', 'CUSTOM'] })
  @IsOptional()
  @IsIn(['FEE_DUE', 'ATTENDANCE_ALERT', 'EXAM_UPCOMING', 'CUSTOM'])
  category?: string;

  @ApiPropertyOptional({ example: 'HIGH', enum: ['LOW', 'MEDIUM', 'HIGH', 'URGENT'] })
  @IsOptional()
  @IsIn(['LOW', 'MEDIUM', 'HIGH', 'URGENT'])
  priority?: string;

  @ApiPropertyOptional({ example: '2026-11-25T17:00:00.000Z' })
  @IsOptional()
  @IsDateString()
  dueDate?: string;

  @ApiPropertyOptional({ example: '2026-11-25T09:00:00.000Z' })
  @IsOptional()
  @IsDateString()
  remindAt?: string;

  @ApiPropertyOptional({ example: 'Exam' })
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

