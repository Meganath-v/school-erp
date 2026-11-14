import { IsNotEmpty, IsOptional, IsString, IsBoolean, IsNumber, IsDateString } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class UpdateSchoolDto {
  @ApiPropertyOptional({ example: 'Oakridge International School' })
  @IsOptional()
  @IsString()
  name?: string;

  @ApiPropertyOptional({ example: '123 Campus Avenue, Whitefield, Bangalore' })
  @IsOptional()
  @IsString()
  address?: string;

  @ApiPropertyOptional({ example: 'contact@oakridge.edu' })
  @IsOptional()
  @IsString()
  contactEmail?: string;

  @ApiPropertyOptional({ example: '+91 80 1234 5678' })
  @IsOptional()
  @IsString()
  contactPhone?: string;

  @ApiPropertyOptional({ example: 'INR' })
  @IsOptional()
  @IsString()
  currency?: string;

  @ApiPropertyOptional({ example: 'Asia/Kolkata' })
  @IsOptional()
  @IsString()
  timezone?: string;
}

export class CreateAcademicYearDto {
  @ApiProperty({ example: '2026-2027' })
  @IsNotEmpty()
  @IsString()
  name: string;

  @ApiProperty({ example: '2026-06-01' })
  @IsNotEmpty()
  @IsDateString()
  startDate: string;

  @ApiProperty({ example: '2027-04-30' })
  @IsNotEmpty()
  @IsDateString()
  endDate: string;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  isCurrent?: boolean;
}

export class CreateAcademicTermDto {
  @ApiProperty({ description: 'Parent Academic Year ID' })
  @IsNotEmpty()
  @IsString()
  academicYearId: string;

  @ApiProperty({ example: 'Term 1' })
  @IsNotEmpty()
  @IsString()
  name: string;

  @ApiProperty({ example: 'T1' })
  @IsNotEmpty()
  @IsString()
  code: string;

  @ApiProperty({ example: '2026-06-01' })
  @IsNotEmpty()
  @IsDateString()
  startDate: string;

  @ApiProperty({ example: '2026-10-31' })
  @IsNotEmpty()
  @IsDateString()
  endDate: string;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  isCurrent?: boolean;
}

export class CreateCampusDto {
  @ApiProperty({ example: 'North Campus' })
  @IsNotEmpty()
  @IsString()
  name: string;

  @ApiProperty({ example: 'NORTH' })
  @IsNotEmpty()
  @IsString()
  code: string;

  @ApiPropertyOptional({ example: 'Sector 4, Phase 2, Bangalore' })
  @IsOptional()
  @IsString()
  address?: string;

  @ApiPropertyOptional({ example: '+91 80 9876 5432' })
  @IsOptional()
  @IsString()
  contactPhone?: string;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  isMain?: boolean;
}

export class CreateClassDto {
  @ApiProperty({ example: 'Grade 10' })
  @IsNotEmpty()
  @IsString()
  name: string;

  @ApiProperty({ example: 'G10' })
  @IsNotEmpty()
  @IsString()
  code: string;

  @ApiPropertyOptional({ default: 0 })
  @IsOptional()
  @IsNumber()
  orderIndex?: number;
}

export class CreateSectionDto {
  @ApiProperty({ description: 'Parent Class ID' })
  @IsNotEmpty()
  @IsString()
  classId: string;

  @ApiProperty({ example: 'Section A' })
  @IsNotEmpty()
  @IsString()
  name: string;

  @ApiPropertyOptional({ example: 'Room 204' })
  @IsOptional()
  @IsString()
  room?: string;

  @ApiPropertyOptional({ default: 40 })
  @IsOptional()
  @IsNumber()
  capacity?: number;
}

export class CreateSubjectDto {
  @ApiProperty({ example: 'Mathematics' })
  @IsNotEmpty()
  @IsString()
  name: string;

  @ApiProperty({ example: 'MATH101' })
  @IsNotEmpty()
  @IsString()
  code: string;

  @ApiPropertyOptional({ example: 'CORE', enum: ['CORE', 'ELECTIVE'] })
  @IsOptional()
  @IsString()
  type?: string;

  @ApiPropertyOptional({ description: 'Optional Class ID to link subject to class' })
  @IsOptional()
  @IsString()
  classId?: string;
}

