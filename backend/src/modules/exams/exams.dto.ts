import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { ArrayNotEmpty, IsArray, IsBoolean, IsDateString, IsInt, IsNotEmpty, IsNumber, IsOptional, IsPositive, IsString, Max, Min, ValidateNested } from 'class-validator';

export class CreateExamDto {
  @ApiProperty({ example: 'Mid-Term Examination 2026', description: 'Exam name' })
  @IsNotEmpty()
  @IsString()
  name: string;

  @ApiPropertyOptional({ example: 'TERM_1', description: 'Academic term identifier' })
  @IsOptional()
  @IsString()
  term?: string;

  @ApiProperty({ example: '2026-10-10', description: 'Exam start date (ISO 8601)' })
  @IsDateString()
  startDate: string;

  @ApiProperty({ example: '2026-10-20', description: 'Exam end date (ISO 8601)' })
  @IsDateString()
  endDate: string;

  @ApiPropertyOptional({ example: 'academic-year-uuid', description: 'Academic year UUID' })
  @IsOptional()
  @IsString()
  academicYearId?: string;
}

export class AddExamSubjectDto {
  @ApiProperty({ example: 'class-uuid-1', description: 'Class UUID' })
  @IsNotEmpty()
  @IsString()
  classId: string;

  @ApiProperty({ example: 'subject-uuid-1', description: 'Subject UUID' })
  @IsNotEmpty()
  @IsString()
  subjectId: string;

  @ApiProperty({ example: '2026-10-12', description: 'Examination date (ISO 8601)' })
  @IsDateString()
  examDate: string;

  @ApiPropertyOptional({ example: 100, description: 'Maximum possible marks' })
  @IsOptional()
  @IsInt()
  @IsPositive()
  maxMarks?: number;

  @ApiPropertyOptional({ example: 40, description: 'Minimum passing marks' })
  @IsOptional()
  @IsInt()
  @IsPositive()
  passMarks?: number;
}

export class MarkEntryItemDto {
  @ApiProperty({ example: 'student-uuid-1', description: 'Student UUID' })
  @IsNotEmpty()
  @IsString()
  studentId: string;

  @ApiPropertyOptional({ example: 85, description: 'Marks obtained by student (0 to maxMarks)' })
  @IsOptional()
  @IsNumber()
  @Min(0)
  marksObtained?: number;

  @ApiPropertyOptional({ example: false, description: 'True if student was absent for the exam' })
  @IsOptional()
  @IsBoolean()
  isAbsent?: boolean;

  @ApiPropertyOptional({ example: 'Excellent performance' })
  @IsOptional()
  @IsString()
  remarks?: string;
}

export class EnterMarksDto {
  @ApiProperty({ type: [MarkEntryItemDto], description: 'Array of marks entries for enrolled students' })
  @IsArray()
  @ArrayNotEmpty()
  @ValidateNested({ each: true })
  @Type(() => MarkEntryItemDto)
  marks: MarkEntryItemDto[];
}

export class ImportMarksRowDto {
  @ApiProperty({ example: 'ADM-2026-001', description: 'Student admission number' })
  @IsNotEmpty()
  @IsString()
  admissionNo: string;

  @ApiPropertyOptional({ example: 'Aarav Sharma' })
  @IsOptional()
  @IsString()
  studentName?: string;

  @ApiPropertyOptional({ example: 85, description: 'Marks obtained (numeric or string from sheet)' })
  @IsOptional()
  marksObtained?: any;

  @ApiPropertyOptional({ example: false })
  @IsOptional()
  @IsBoolean()
  isAbsent?: boolean;

  @ApiPropertyOptional({ example: 'Consistent work' })
  @IsOptional()
  @IsString()
  remarks?: string;
}

export class ImportMarksDto {
  @ApiProperty({ type: [ImportMarksRowDto], description: 'Parsed spreadsheet rows to import' })
  @IsArray()
  @ArrayNotEmpty()
  @ValidateNested({ each: true })
  @Type(() => ImportMarksRowDto)
  rows: ImportMarksRowDto[];
}

