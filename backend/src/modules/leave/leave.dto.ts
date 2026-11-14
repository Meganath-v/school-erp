import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsIn, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

export const LEAVE_DECISIONS = ['APPROVED', 'REJECTED', 'MORE_INFO_REQUIRED'];

export class CreateLeaveRequestDto {
  @ApiProperty({ example: 'student-uuid-1', description: 'Student UUID applying for leave' })
  @IsNotEmpty()
  @IsString()
  studentId: string;

  @ApiProperty({ example: '2026-11-20', description: 'Leave start date (ISO 8601)' })
  @IsDateString()
  startDate: string;

  @ApiProperty({ example: '2026-11-22', description: 'Leave end date (ISO 8601)' })
  @IsDateString()
  endDate: string;

  @ApiProperty({ example: 'Attending family wedding ceremony', description: 'Reason for leave application' })
  @IsNotEmpty()
  @IsString()
  @MaxLength(500)
  reason: string;

  @ApiPropertyOptional({ example: 'MEDICAL', enum: ['MEDICAL', 'CASUAL', 'FAMILY', 'OTHER'] })
  @IsOptional()
  @IsString()
  leaveType?: string;

  @ApiPropertyOptional({ example: 'https://example.com/docs/medical_cert.pdf' })
  @IsOptional()
  @IsString()
  supportingDocUrl?: string;
}

export class DecideLeaveDto {
  @ApiProperty({ example: 'APPROVED', enum: LEAVE_DECISIONS })
  @IsIn(LEAVE_DECISIONS)
  status: 'APPROVED' | 'REJECTED' | 'MORE_INFO_REQUIRED';

  @ApiPropertyOptional({ example: 'Granted. Ensure homework is caught up upon return.' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  remarks?: string;
}

