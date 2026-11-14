import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsIn, IsInt, IsNotEmpty, IsOptional, IsPositive, IsString } from 'class-validator';
import { PaginationQueryDto } from '../../common/dto/pagination.dto';

export class CreateStudentAdmissionDto {
  @ApiPropertyOptional({ example: 'ADM-2026-001', description: 'Custom admission number. Auto-generated if omitted.' })
  @IsOptional()
  @IsString()
  admissionNo?: string;

  @ApiProperty({ example: 'Aarav', description: 'Student first name' })
  @IsNotEmpty()
  @IsString()
  firstName: string;

  @ApiProperty({ example: 'Sharma', description: 'Student last name' })
  @IsNotEmpty()
  @IsString()
  lastName: string;

  @ApiPropertyOptional({ example: '2012-05-15', description: 'Date of birth (ISO 8601)' })
  @IsOptional()
  @IsDateString()
  dob?: string;

  @ApiPropertyOptional({ example: 'MALE', enum: ['MALE', 'FEMALE', 'OTHER'] })
  @IsOptional()
  @IsIn(['MALE', 'FEMALE', 'OTHER'])
  gender?: string;

  @ApiPropertyOptional({ example: 'O+' })
  @IsOptional()
  @IsString()
  bloodGroup?: string;

  @ApiPropertyOptional({ example: '123 Palm Grove Avenue' })
  @IsOptional()
  @IsString()
  address?: string;

  @ApiPropertyOptional({ example: '+91 9876543210' })
  @IsOptional()
  @IsString()
  emergencyContact?: string;

  @ApiPropertyOptional({ example: 'class-uuid-1', description: 'Class to enroll student into' })
  @IsOptional()
  @IsString()
  classId?: string;

  @ApiPropertyOptional({ example: 'section-uuid-1', description: 'Section to enroll student into' })
  @IsOptional()
  @IsString()
  sectionId?: string;

  @ApiPropertyOptional({ example: 1, description: 'Class roll number' })
  @IsOptional()
  @IsInt()
  @IsPositive()
  rollNo?: number;

  @ApiPropertyOptional({ example: 'Rajesh Sharma', description: 'Primary guardian name' })
  @IsOptional()
  @IsString()
  guardianName?: string;

  @ApiPropertyOptional({ example: 'FATHER', description: 'Guardian relationship' })
  @IsOptional()
  @IsString()
  guardianRelation?: string;

  @ApiPropertyOptional({ example: '+91 9876543210' })
  @IsOptional()
  @IsString()
  guardianPhone?: string;

  @ApiPropertyOptional({ example: 'rajesh.sharma@example.com' })
  @IsOptional()
  @IsString()
  guardianEmail?: string;
}

export class UpdateStudentDto {
  @ApiPropertyOptional({ example: 'Aarav' })
  @IsOptional()
  @IsString()
  firstName?: string;

  @ApiPropertyOptional({ example: 'Sharma' })
  @IsOptional()
  @IsString()
  lastName?: string;

  @ApiPropertyOptional({ example: '2012-05-15' })
  @IsOptional()
  @IsDateString()
  dob?: string;

  @ApiPropertyOptional({ example: 'MALE', enum: ['MALE', 'FEMALE', 'OTHER'] })
  @IsOptional()
  @IsIn(['MALE', 'FEMALE', 'OTHER'])
  gender?: string;

  @ApiPropertyOptional({ example: 'O+' })
  @IsOptional()
  @IsString()
  bloodGroup?: string;

  @ApiPropertyOptional({ example: '123 Palm Grove Avenue' })
  @IsOptional()
  @IsString()
  address?: string;

  @ApiPropertyOptional({ example: '+91 9876543210' })
  @IsOptional()
  @IsString()
  emergencyContact?: string;

  @ApiPropertyOptional({ example: 'ACTIVE', enum: ['ACTIVE', 'INACTIVE', 'ALUMNI', 'TRANSFERRED'] })
  @IsOptional()
  @IsIn(['ACTIVE', 'INACTIVE', 'ALUMNI', 'TRANSFERRED'])
  status?: string;
}

export class GetStudentsFilterDto extends PaginationQueryDto {
  @ApiPropertyOptional({ description: 'Filter by Class ID' })
  @IsOptional()
  @IsString()
  classId?: string;

  @ApiPropertyOptional({ description: 'Filter by Section ID' })
  @IsOptional()
  @IsString()
  sectionId?: string;
}

