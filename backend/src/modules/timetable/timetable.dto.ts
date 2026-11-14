import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsInt, IsNotEmpty, IsOptional, IsString, Max, Min } from 'class-validator';

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

