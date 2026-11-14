import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsDateString, IsEmail, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateStaffDto {
  @ApiPropertyOptional({ example: 'EMP-101', description: 'Unique staff employee number' })
  @IsOptional()
  @IsString()
  employeeNo?: string;

  @ApiProperty({ example: 'Robert', description: 'First name' })
  @IsNotEmpty()
  @IsString()
  firstName: string;

  @ApiProperty({ example: 'Smith', description: 'Last name' })
  @IsNotEmpty()
  @IsString()
  lastName: string;

  @ApiProperty({ example: 'Senior Mathematics Teacher', description: 'Designation / job title' })
  @IsNotEmpty()
  @IsString()
  designation: string;

  @ApiPropertyOptional({ example: 'Mathematics', description: 'Department name' })
  @IsOptional()
  @IsString()
  department?: string;

  @ApiPropertyOptional({ example: '+91 9876543210', description: 'Contact phone number' })
  @IsOptional()
  @IsString()
  phone?: string;

  @ApiPropertyOptional({ example: 'robert.smith@oakridge.edu', description: 'Work email address' })
  @IsOptional()
  @IsEmail()
  email?: string;

  @ApiPropertyOptional({ example: '2026-06-01', description: 'Joining date (ISO 8601)' })
  @IsOptional()
  @IsDateString()
  joiningDate?: string;
}

export class CreateAssignmentDto {
  @ApiProperty({ example: 'staff-uuid-1', description: 'Staff member UUID' })
  @IsNotEmpty()
  @IsString()
  staffId: string;

  @ApiProperty({ example: 'class-uuid-1', description: 'Class UUID' })
  @IsNotEmpty()
  @IsString()
  classId: string;

  @ApiProperty({ example: 'section-uuid-1', description: 'Section UUID' })
  @IsNotEmpty()
  @IsString()
  sectionId: string;

  @ApiPropertyOptional({ example: 'subject-uuid-1', description: 'Subject UUID (optional if assigning class teacher only)' })
  @IsOptional()
  @IsString()
  subjectId?: string;

  @ApiPropertyOptional({ example: true, description: 'Whether the staff is designated as the primary Class Teacher' })
  @IsOptional()
  @IsBoolean()
  isClassTeacher?: boolean;
}

