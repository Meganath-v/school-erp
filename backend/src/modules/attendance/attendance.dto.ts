import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { ArrayNotEmpty, IsArray, IsDateString, IsIn, IsInt, IsNotEmpty, IsOptional, IsString, Max, Min, ValidateNested } from 'class-validator';

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

