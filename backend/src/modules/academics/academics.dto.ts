import { IsNotEmpty, IsOptional, IsString, IsInt, Min, Max } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateLessonPlanDto {
  @ApiProperty({ description: 'Class ID' })
  @IsNotEmpty()
  @IsString()
  classId: string;

  @ApiProperty({ description: 'Subject ID' })
  @IsNotEmpty()
  @IsString()
  subjectId: string;

  @ApiPropertyOptional({ description: 'Assigned Teacher Staff ID' })
  @IsOptional()
  @IsString()
  teacherId?: string;

  @ApiProperty({ example: 1, minimum: 1 })
  @IsInt()
  @Min(1)
  unitNumber: number;

  @ApiProperty({ example: 'Unit 1: Differential Calculus' })
  @IsNotEmpty()
  @IsString()
  unitTitle: string;

  @ApiProperty({ example: 'Derivatives of Trigonometric Functions' })
  @IsNotEmpty()
  @IsString()
  topic: string;

  @ApiPropertyOptional({ example: 'CO1: Students understand rate of change principles' })
  @IsOptional()
  @IsString()
  learningObjectives?: string;

  @ApiPropertyOptional({ example: 4, default: 4 })
  @IsOptional()
  @IsInt()
  @Min(1)
  plannedHours?: number;
}

export class UpdateLessonPlanProgressDto {
  @ApiProperty({ example: 3, description: 'Updated number of conducted teaching hours' })
  @IsInt()
  @Min(0)
  conductedHours: number;

  @ApiPropertyOptional({ example: 'IN_PROGRESS', enum: ['PENDING', 'IN_PROGRESS', 'COMPLETED'] })
  @IsOptional()
  @IsString()
  status?: string;
}

export class CreateTeachingDiaryDto {
  @ApiPropertyOptional({ description: 'Class ID' })
  @IsOptional()
  @IsString()
  classId?: string;

  @ApiPropertyOptional({ description: 'Section ID' })
  @IsOptional()
  @IsString()
  sectionId?: string;

  @ApiPropertyOptional({ description: 'Subject ID' })
  @IsOptional()
  @IsString()
  subjectId?: string;

  @ApiPropertyOptional({ description: 'Teacher Staff ID' })
  @IsOptional()
  @IsString()
  teacherId?: string;

  @ApiPropertyOptional({ example: 2, description: 'Period number conducted' })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(8)
  periodNumber?: number;

  @ApiPropertyOptional({ example: 'Derived roots of cubic equations' })
  @IsOptional()
  @IsString()
  topicTaught?: string;

  @ApiPropertyOptional({ example: 'Derived roots of cubic equations' })
  @IsOptional()
  @IsString()
  topicCovered?: string;

  @ApiPropertyOptional({ example: 'LECTURE', enum: ['LECTURE', 'LAB', 'FLIPPED_CLASS', 'GROUP_DISCUSSION'] })
  @IsOptional()
  @IsString()
  methodology?: string;

  @ApiPropertyOptional({ example: 'Interactive Whiteboard' })
  @IsOptional()
  @IsString()
  teachingMethod?: string;

  @ApiPropertyOptional({ example: 'Homework assigned: Exercises 1-5' })
  @IsOptional()
  @IsString()
  remarks?: string;

  @ApiPropertyOptional({ example: 'Exercise 4.2 Questions 1 to 8' })
  @IsOptional()
  @IsString()
  homeworkGiven?: string;
}

export class CreateCourseMaterialDto {
  @ApiProperty({ description: 'Subject ID' })
  @IsNotEmpty()
  @IsString()
  subjectId: string;

  @ApiProperty({ example: 'Chapter 2 Comprehensive Study Notes' })
  @IsNotEmpty()
  @IsString()
  title: string;

  @ApiPropertyOptional({ example: 1, default: 1 })
  @IsOptional()
  @IsInt()
  @Min(1)
  unitNumber?: number;

  @ApiPropertyOptional({ example: 'PDF', enum: ['PDF', 'SLIDES', 'DOC', 'VIDEO_LINK'] })
  @IsOptional()
  @IsString()
  fileType?: string;

  @ApiProperty({ example: 'https://docs.erp.com/notes.pdf' })
  @IsNotEmpty()
  @IsString()
  fileUrl: string;
}

export class CreateCourseOutcomeDto {
  @ApiProperty({ example: 'CO1', description: 'Course Outcome code' })
  @IsNotEmpty()
  @IsString()
  code: string;

  @ApiProperty({ example: 'Analyze algorithm time and space complexity using Big-O notation' })
  @IsNotEmpty()
  @IsString()
  description: string;

  @ApiProperty({
    example: 'ANALYZE',
    enum: ['REMEMBER', 'UNDERSTAND', 'APPLY', 'ANALYZE', 'EVALUATE', 'CREATE'],
  })
  @IsNotEmpty()
  @IsString()
  bloomLevel: string;

  @ApiPropertyOptional({ example: 75, description: 'Target attainment percentage threshold' })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100)
  targetAttainment?: number;
}


