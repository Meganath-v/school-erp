import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsInt, IsNotEmpty, IsOptional, IsPositive, IsString, IsUrl, Min } from 'class-validator';

export class CreateAssignmentDto {
  @ApiProperty({ example: 'Quadratic Equations Practice Set', description: 'Assignment title' })
  @IsNotEmpty()
  @IsString()
  title: string;

  @ApiPropertyOptional({ example: 'Complete exercises 4.1 to 4.3 from NCERT textbook' })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional({ example: 'class-uuid-1', description: 'Target Class UUID' })
  @IsOptional()
  @IsString()
  classId?: string;

  @ApiPropertyOptional({ example: 'section-uuid-1', description: 'Target Section UUID' })
  @IsOptional()
  @IsString()
  sectionId?: string;

  @ApiPropertyOptional({ example: 'subject-uuid-1', description: 'Subject UUID' })
  @IsOptional()
  @IsString()
  subjectId?: string;

  @ApiPropertyOptional({ example: 'staff-uuid-1', description: 'Teacher UUID' })
  @IsOptional()
  @IsString()
  teacherId?: string;

  @ApiProperty({ example: '2026-11-20T23:59:59.000Z', description: 'Submission due date (ISO 8601)' })
  @IsDateString()
  dueDate: string;

  @ApiPropertyOptional({ example: 100, description: 'Maximum marks for the assignment' })
  @IsOptional()
  @IsInt()
  @IsPositive()
  maxMarks?: number;
}

export class SubmitAssignmentDto {
  @ApiProperty({ example: 'student-uuid-1', description: 'Student UUID submitting the work' })
  @IsNotEmpty()
  @IsString()
  studentId: string;

  @ApiPropertyOptional({ example: 'Attached completed handwritten solutions in PDF format' })
  @IsOptional()
  @IsString()
  notes?: string;

  @ApiPropertyOptional({ example: '/uploads/OAK01/solutions.pdf', description: 'File attachment URL' })
  @IsOptional()
  @IsString()
  fileUrl?: string;
}

export class GradeSubmissionDto {
  @ApiProperty({ example: 92, description: 'Marks obtained (whole number)' })
  @IsInt()
  @Min(0)
  marksObtained: number;

  @ApiPropertyOptional({ example: 'Well organized steps and accurate solutions.' })
  @IsOptional()
  @IsString()
  feedback?: string;
}

export class AssignmentFilterDto {
  @ApiPropertyOptional({ description: 'Filter by Class UUID' })
  @IsOptional()
  @IsString()
  classId?: string;

  @ApiPropertyOptional({ description: 'Filter by Section UUID' })
  @IsOptional()
  @IsString()
  sectionId?: string;

  @ApiPropertyOptional({ description: 'Filter by Teacher UUID' })
  @IsOptional()
  @IsString()
  teacherId?: string;
}
