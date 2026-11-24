import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsIn,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export const COMPONENT_TYPES = ['EXAM', 'ASSIGNMENT', 'ATTENDANCE', 'MANUAL'] as const;

export class ComponentDto {
  @ApiPropertyOptional({ description: 'Existing component id (keeps its manual marks)' }) @IsOptional() @IsString() id?: string;
  @ApiProperty({ example: 'Class tests' }) @IsNotEmpty() @IsString() @MaxLength(100) label: string;
  @ApiProperty({ enum: COMPONENT_TYPES }) @IsIn(COMPONENT_TYPES as unknown as string[]) type: string;
  @ApiProperty({ example: 20 }) @IsNumber() @Min(0.5) @Max(1000) weight: number;
  @ApiPropertyOptional({ example: 2 }) @IsOptional() @IsInt() @Min(1) @Max(50) bestOf?: number | null;
  @ApiPropertyOptional({ type: [String], description: 'Exam subject ids (EXAM) or assignment ids (ASSIGNMENT)' })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(50)
  @IsString({ each: true })
  sourceIds?: string[];
}

export class SaveSchemeDto {
  @ApiProperty({ example: 'Internal assessment 2026-27' }) @IsNotEmpty() @IsString() @MaxLength(150) name: string;
  @ApiPropertyOptional({ description: 'Limit to one class; omit for every class of the subject' }) @IsOptional() @IsString() classId?: string | null;
  @ApiPropertyOptional({ example: 40 }) @IsOptional() @IsNumber() @Min(0) @Max(100) passPercent?: number;
  @ApiProperty({ type: [ComponentDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(20)
  @ValidateNested({ each: true })
  @Type(() => ComponentDto)
  components: ComponentDto[];
}

export class ManualMarkEntryDto {
  @ApiProperty() @IsString() studentId: string;
  @ApiPropertyOptional({ nullable: true }) @IsOptional() @IsNumber() @Min(0) marks: number | null;
}

export class SaveManualMarksDto {
  @ApiProperty({ type: [ManualMarkEntryDto] })
  @IsArray()
  @ArrayMaxSize(5000)
  @ValidateNested({ each: true })
  @Type(() => ManualMarkEntryDto)
  entries: ManualMarkEntryDto[];
}

// ---------------------------------------------------------------- quizzes

export class SaveQuizDto {
  @ApiProperty() @IsNotEmpty() @IsString() @MaxLength(200) title: string;
  @ApiProperty() @IsString() subjectId: string;
  @ApiProperty() @IsString() classId: string;
  @ApiPropertyOptional({ nullable: true }) @IsOptional() @IsString() sectionId?: string | null;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(2000) instructions?: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) @Max(600) durationMinutes?: number | null;
  @ApiPropertyOptional() @IsOptional() @IsDateString() opensAt?: string | null;
  @ApiPropertyOptional() @IsOptional() @IsDateString() closesAt?: string | null;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() showAnswers?: boolean;
}

export class QuizQuestionDto {
  @ApiProperty() @IsString() questionId: string;
  @ApiPropertyOptional({ description: 'Defaults to the bank marks' }) @IsOptional() @IsNumber() @Min(0.25) @Max(100) marks?: number;
}

export class SetQuizQuestionsDto {
  @ApiProperty({ type: [QuizQuestionDto] })
  @IsArray()
  @ArrayMaxSize(200)
  @ValidateNested({ each: true })
  @Type(() => QuizQuestionDto)
  questions: QuizQuestionDto[];
}

export class SubmitQuizDto {
  @ApiProperty({ description: '{ questionId: chosen option index }' })
  @IsNotEmpty()
  answers: Record<string, number>;
}
