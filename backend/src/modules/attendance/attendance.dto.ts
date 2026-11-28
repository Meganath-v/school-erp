import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { ArrayNotEmpty, IsArray, IsDateString, IsIn, IsInt, IsNotEmpty, IsOptional, IsString, Matches, Max, MaxLength, Min, ValidateNested } from 'class-validator';

export class StudentRecordAttendanceDto {
  @ApiProperty({ example: 'student-uuid-1', description: 'Student UUID' })
  @IsNotEmpty()
  @IsString()
  studentId: string;

  @ApiProperty({ example: 'PRESENT', enum: ['PRESENT', 'ABSENT', 'LATE', 'EXCUSED', 'HALF_DAY'] })
  @IsIn(['PRESENT', 'ABSENT', 'LATE', 'EXCUSED', 'HALF_DAY'])
  status: string;

  @ApiPropertyOptional({ example: 'Medical leave approved' })
  @IsOptional()
  @IsString()
  remarks?: string;
}

export class SaveAttendanceDto {
  @ApiProperty({ example: 'section-uuid-1', description: 'Section UUID' })
  @IsNotEmpty()
  @IsString()
  sectionId: string;

  @ApiPropertyOptional({ example: '2026-11-14', description: 'Attendance date (ISO 8601). Defaults to today.' })
  @IsOptional()
  @IsDateString()
  date?: string;

  @ApiProperty({ type: [StudentRecordAttendanceDto], description: 'List of student attendance records for this session' })
  @IsArray()
  @ArrayNotEmpty()
  @ValidateNested({ each: true })
  @Type(() => StudentRecordAttendanceDto)
  records: StudentRecordAttendanceDto[];
}

export class AttendanceFilterDto {
  @ApiPropertyOptional({ description: 'Filter by Section UUID' })
  @IsOptional()
  @IsString()
  sectionId?: string;

  @ApiPropertyOptional({ example: 11, description: 'Month (1-12)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(12)
  month?: number;

  @ApiPropertyOptional({ example: 2026, description: 'Year (YYYY)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(2000)
  @Max(2100)
  year?: number;
}

export class CorrectAttendanceRecordDto {
  @ApiProperty({ example: 'PRESENT', enum: ['PRESENT', 'ABSENT', 'LATE', 'EXCUSED', 'HALF_DAY'] })
  @IsIn(['PRESENT', 'ABSENT', 'LATE', 'EXCUSED', 'HALF_DAY'])
  status: string;

  @ApiPropertyOptional({ example: 'Medical certificate submitted, approved by Principal' })
  @IsOptional()
  @IsString()
  remarks?: string;

  @ApiPropertyOptional({ example: 'Doctor certificate provided' })
  @IsOptional()
  @IsString()
  reason?: string;
}



export class PeriodRecordDto {
  @ApiProperty({ example: 'student-uuid-1' })
  @IsNotEmpty()
  @IsString()
  studentId: string;

  @ApiProperty({ example: 'PRESENT', enum: ['PRESENT', 'ABSENT', 'LATE', 'EXCUSED'] })
  @IsIn(['PRESENT', 'ABSENT', 'LATE', 'EXCUSED'])
  status: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(300)
  remarks?: string;
}

export class SavePeriodAttendanceDto {
  @ApiProperty({ description: 'Section UUID' })
  @IsNotEmpty()
  @IsString()
  sectionId: string;

  @ApiProperty({ example: '2026-11-30' })
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'date must be YYYY-MM-DD' })
  date: string;

  @ApiProperty({ example: 2 })
  @IsInt()
  @Min(1)
  @Max(12)
  periodNumber: number;

  @ApiProperty({ type: [PeriodRecordDto] })
  @IsArray()
  @ArrayNotEmpty()
  @ValidateNested({ each: true })
  @Type(() => PeriodRecordDto)
  records: PeriodRecordDto[];
}

export class PeriodAttendanceQueryDto {
  @ApiProperty({ description: 'Section UUID' })
  @IsNotEmpty()
  @IsString()
  sectionId: string;

  @ApiProperty({ example: '2026-11-30' })
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'date must be YYYY-MM-DD' })
  date: string;

  @ApiProperty({ example: 2 })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(12)
  periodNumber: number;
}
