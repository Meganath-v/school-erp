import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { ArrayMaxSize, IsArray, IsBoolean, IsInt, IsNotEmpty, IsOptional, IsString, Matches, Max, MaxLength, Min, ValidateNested } from 'class-validator';
import { DATE_RE, TIME_RE } from './schedule.util';

export class CreateTimetableEntryDto {
  @ApiProperty({ example: 'section-uuid-1', description: 'Section UUID' })
  @IsNotEmpty()
  @IsString()
  sectionId: string;

  @ApiProperty({ example: 'subject-uuid-1', description: 'Subject UUID' })
  @IsNotEmpty()
  @IsString()
  subjectId: string;

  @ApiProperty({ example: 'staff-uuid-1', description: 'Assigned Staff UUID' })
  @IsNotEmpty()
  @IsString()
  staffId: string;

  @ApiProperty({ example: 1, description: 'Day of week (1=Monday, 2=Tuesday, ..., 6=Saturday, 7=Sunday)' })
  @IsInt()
  @Min(1)
  @Max(7)
  dayOfWeek: number;

  @ApiProperty({ example: 1, description: 'Period sequence number (1, 2, 3...)' })
  @IsInt()
  @Min(1)
  @Max(12)
  periodNumber: number;

  @ApiProperty({ example: '09:00', description: 'Start time in HH:mm format' })
  @IsNotEmpty()
  @IsString()
  startTime: string;

  @ApiProperty({ example: '09:45', description: 'End time in HH:mm format' })
  @IsNotEmpty()
  @IsString()
  endTime: string;

  @ApiPropertyOptional({ example: 'Room 302', description: 'Classroom / Lab room identifier' })
  @IsOptional()
  @IsString()
  room?: string;
}

export class TimetableFilterDto {
  @ApiPropertyOptional({ description: 'Filter by Section UUID' })
  @IsOptional()
  @IsString()
  sectionId?: string;

  @ApiPropertyOptional({ description: 'Filter by Staff UUID' })
  @IsOptional()
  @IsString()
  staffId?: string;

  @ApiPropertyOptional({ description: 'Filter by Class UUID' })
  @IsOptional()
  @IsString()
  classId?: string;
}


export class TimetablePeriodDto {
  @ApiProperty({ example: 1, description: '1 = Monday … 7 = Sunday' })
  @IsInt()
  @Min(1)
  @Max(7)
  dayOfWeek: number;

  @ApiProperty({ example: 1 })
  @IsInt()
  @Min(1)
  @Max(12)
  periodNumber: number;

  @ApiProperty({ example: '09:00' })
  @Matches(TIME_RE, { message: 'startTime must be HH:mm' })
  startTime: string;

  @ApiProperty({ example: '09:45' })
  @Matches(TIME_RE, { message: 'endTime must be HH:mm' })
  endTime: string;

  @ApiPropertyOptional({ example: 'Period 1' })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  label?: string;
}

export class SaveTimetablePeriodsDto {
  @ApiProperty({ type: [TimetablePeriodDto] })
  @IsArray()
  @ArrayMaxSize(84)
  @ValidateNested({ each: true })
  @Type(() => TimetablePeriodDto)
  periods: TimetablePeriodDto[];

  @ApiPropertyOptional({ description: 'Also clear class timetable slots in periods that are removed' })
  @IsOptional()
  @IsBoolean()
  removeAssignedSlots?: boolean;
}

export class SetClassSlotDto {
  @ApiProperty({ example: 1 })
  @IsInt()
  @Min(1)
  @Max(7)
  dayOfWeek: number;

  @ApiProperty({ example: 1 })
  @IsInt()
  @Min(1)
  @Max(12)
  periodNumber: number;

  @ApiProperty({ description: 'Subject UUID' })
  @IsString()
  @IsNotEmpty()
  subjectId: string;

  @ApiProperty({ example: 'teacher.jones@oakridge.edu', description: "Teacher's username or email" })
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  teacher: string;

  @ApiPropertyOptional({ example: 'Room 302' })
  @IsOptional()
  @IsString()
  @MaxLength(60)
  room?: string;
}

export class SetSubstitutionDto {
  @ApiProperty({ example: '2026-11-30' })
  @Matches(DATE_RE, { message: 'date must be YYYY-MM-DD' })
  date: string;

  @ApiProperty({ example: 2 })
  @IsInt()
  @Min(1)
  @Max(12)
  periodNumber: number;

  @ApiProperty({ example: 'teacher.jones@oakridge.edu', description: "Substitute teacher's username or email" })
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  teacher: string;

  @ApiPropertyOptional({ description: 'Subject taught that day (defaults to the timetable subject)' })
  @IsOptional()
  @IsString()
  subjectId?: string;

  @ApiPropertyOptional({ example: 'Mrs Smith on leave' })
  @IsOptional()
  @IsString()
  @MaxLength(300)
  reason?: string;
}

export class DateQueryDto {
  @ApiPropertyOptional({ example: '2026-11-30', description: 'Defaults to today in the school time zone' })
  @IsOptional()
  @Matches(DATE_RE, { message: 'date must be YYYY-MM-DD' })
  date?: string;
}

export class SlotQueryDto {
  @ApiProperty({ example: 1 })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(7)
  dayOfWeek: number;

  @ApiProperty({ example: 1 })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(12)
  periodNumber: number;
}

export class SubstitutionQueryDto {
  @ApiProperty({ example: '2026-11-30' })
  @Matches(DATE_RE, { message: 'date must be YYYY-MM-DD' })
  date: string;

  @ApiProperty({ example: 2 })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(12)
  periodNumber: number;
}
