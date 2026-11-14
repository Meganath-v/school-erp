import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsIn, IsNumber, IsOptional, IsString } from 'class-validator';
import { Type } from 'class-transformer';

export class ReportFilterDto {
  @ApiPropertyOptional({ description: 'Academic Year UUID' })
  @IsOptional()
  @IsString()
  academicYearId?: string;

  @ApiPropertyOptional({ description: 'Class UUID' })
  @IsOptional()
  @IsString()
  classId?: string;

  @ApiPropertyOptional({ description: 'Section UUID' })
  @IsOptional()
  @IsString()
  sectionId?: string;

  @ApiPropertyOptional({ description: 'Subject UUID' })
  @IsOptional()
  @IsString()
  subjectId?: string;

  @ApiPropertyOptional({ description: 'Examination UUID' })
  @IsOptional()
  @IsString()
  examId?: string;

  @ApiPropertyOptional({ description: 'Filter range start date (YYYY-MM-DD)' })
  @IsOptional()
  @IsDateString()
  startDate?: string;

  @ApiPropertyOptional({ description: 'Filter range end date (YYYY-MM-DD)' })
  @IsOptional()
  @IsDateString()
  endDate?: string;

  @ApiPropertyOptional({ description: 'Status filter (e.g. ACTIVE, PENDING, PAID, RESOLVED)' })
  @IsOptional()
  @IsString()
  status?: string;

  @ApiPropertyOptional({ description: 'Fee or feedback category' })
  @IsOptional()
  @IsString()
  category?: string;

  @ApiPropertyOptional({ description: 'Department (e.g. Science, Mathematics, Humanities)' })
  @IsOptional()
  @IsString()
  department?: string;

  @ApiPropertyOptional({ description: 'Staff member UUID' })
  @IsOptional()
  @IsString()
  staffId?: string;

  @ApiPropertyOptional({ description: 'Student UUID (for transcript / report card)' })
  @IsOptional()
  @IsString()
  studentId?: string;

  @ApiPropertyOptional({ description: 'Attendance condonation threshold (default: 75)' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  threshold?: number;

  @ApiPropertyOptional({ description: 'Keyword search query' })
  @IsOptional()
  @IsString()
  search?: string;
}

export class ExportReportDto extends ReportFilterDto {
  @ApiPropertyOptional({
    description: 'Report identifier',
    enum: [
      'student-strength',
      'admissions',
      'staff-directory',
      'attendance-summary',
      'attendance-defaulters',
      'exam-performance',
      'class-broadsheet',
      'fee-collections',
      'outstanding-fees',
      'teacher-workload',
      'assignment-performance',
      'feedback-resolution',
    ],
  })
  @IsString()
  reportType: string;

  @ApiPropertyOptional({ description: 'Export format: excel or csv', enum: ['excel', 'csv'], default: 'excel' })
  @IsOptional()
  @IsIn(['excel', 'csv'])
  format?: string;
}
