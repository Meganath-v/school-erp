import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsIn,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { ASSIGN_MODES, DIFFICULTIES, QUESTION_TYPES } from './ai-exam.constants';

export class SaveAiTestDto {
  @ApiProperty() @IsNotEmpty() @IsString() @MaxLength(200) title: string;
  @ApiPropertyOptional({ description: 'Defaults to the current academic year' }) @IsOptional() @IsString() academicYearId?: string;
  @ApiProperty() @IsString() classId: string;
  @ApiPropertyOptional({ nullable: true }) @IsOptional() @IsString() sectionId?: string | null;
  @ApiProperty() @IsString() subjectId: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(200) chapter?: string;
  @ApiPropertyOptional({ type: [String] }) @IsOptional() @IsArray() @ArrayMaxSize(30) @IsString({ each: true }) @MaxLength(120, { each: true }) topics?: string[];
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(4000) description?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(4000) instructions?: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) @Max(600) durationMinutes?: number | null;
  @ApiPropertyOptional() @IsOptional() @IsDateString() startsAt?: string | null;
  @ApiPropertyOptional() @IsOptional() @IsDateString() endsAt?: string | null;
  @ApiPropertyOptional({ enum: ASSIGN_MODES }) @IsOptional() @IsIn(ASSIGN_MODES as unknown as string[]) assignMode?: string;
  @ApiPropertyOptional({ type: [String] }) @IsOptional() @IsArray() @ArrayMaxSize(500) @IsString({ each: true }) studentIds?: string[];
  @ApiPropertyOptional() @IsOptional() @IsBoolean() autoSubmit?: boolean;
}

export class RubricDto {
  @ApiProperty() @IsNotEmpty() @IsString() @MaxLength(500) description: string;
  @ApiProperty() @IsNumber() @Min(0.25) @Max(100) marks: number;
}

export class AiQuestionDto {
  @ApiProperty({ enum: QUESTION_TYPES }) @IsIn(QUESTION_TYPES as unknown as string[]) type: string;
  @ApiProperty() @IsNotEmpty() @IsString() @MaxLength(5000) text: string;
  @ApiPropertyOptional({ description: 'URL returned by /files/upload (png/jpg)' })
  @IsOptional()
  @IsString()
  @Matches(/^\/uploads\/[A-Za-z0-9_-]+\/[A-Za-z0-9._-]+\.(png|jpe?g)$/i, { message: 'imageUrl must be an uploaded PNG or JPEG' })
  imageUrl?: string | null;
  @ApiProperty() @IsNumber() @Min(0.25) @Max(100) marks: number;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(200) chapter?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(200) topic?: string;
  @ApiPropertyOptional({ enum: DIFFICULTIES }) @IsOptional() @IsIn(DIFFICULTIES as unknown as string[]) difficulty?: string;
  @ApiPropertyOptional({ type: [String] }) @IsOptional() @IsArray() @ArrayMaxSize(6) @IsString({ each: true }) @MaxLength(500, { each: true }) options?: string[];
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) @Max(5) correctOption?: number | null;
  @ApiPropertyOptional({ description: 'Model answer / correct value' }) @IsOptional() @IsString() @MaxLength(8000) answerKey?: string;
  @ApiPropertyOptional({ type: [String] }) @IsOptional() @IsArray() @ArrayMaxSize(20) @IsString({ each: true }) @MaxLength(2000, { each: true }) acceptableAnswers?: string[];
  @ApiPropertyOptional({ type: [String] }) @IsOptional() @IsArray() @ArrayMaxSize(30) @IsString({ each: true }) @MaxLength(200, { each: true }) keywords?: string[];
  @ApiPropertyOptional({ type: [String] }) @IsOptional() @IsArray() @ArrayMaxSize(30) @IsString({ each: true }) @MaxLength(500, { each: true }) concepts?: string[];
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(4000) explanation?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(2000) partialCredit?: string;
  @ApiPropertyOptional() @IsOptional() @IsNumber() @Min(0) tolerance?: number | null;
  @ApiPropertyOptional({ type: [RubricDto] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @ValidateNested({ each: true })
  @Type(() => RubricDto)
  rubric?: RubricDto[];
}

export class SaveAiQuestionsDto {
  @ApiProperty({ type: [AiQuestionDto] })
  @IsArray()
  @ArrayMaxSize(100)
  @ValidateNested({ each: true })
  @Type(() => AiQuestionDto)
  questions: AiQuestionDto[];
}

export class AssignAiTestDto {
  @ApiProperty({ enum: ASSIGN_MODES }) @IsIn(ASSIGN_MODES as unknown as string[]) assignMode: string;
  @ApiPropertyOptional({ nullable: true }) @IsOptional() @IsString() sectionId?: string | null;
  @ApiPropertyOptional({ type: [String] }) @IsOptional() @IsArray() @ArrayMaxSize(500) @IsString({ each: true }) studentIds?: string[];
}

export class AnswerDto {
  @ApiProperty() @IsString() questionId: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(20000) text?: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) @Max(5) choice?: number | null;
  @ApiPropertyOptional({ enum: ['TYPED', 'VOICE', 'MIXED'] }) @IsOptional() @IsIn(['TYPED', 'VOICE', 'MIXED']) inputMethod?: string;
}

export class SaveAnswersDto {
  @ApiProperty({ type: [AnswerDto] })
  @IsArray()
  @ArrayMaxSize(100)
  @ValidateNested({ each: true })
  @Type(() => AnswerDto)
  answers: AnswerDto[];
}

export class OverrideMarksDto {
  @ApiProperty() @IsNumber() @Min(0) marks: number;
  @ApiProperty({ description: 'Why the marks were changed' }) @IsString() @MinLength(3) @MaxLength(1000) reason: string;
}

export class EvaluateDto {
  @ApiPropertyOptional() @IsOptional() @IsString() submissionId?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() testId?: string;
}

export class AiExamSettingsDto {
  @ApiPropertyOptional() @IsOptional() @IsBoolean() autoEvaluate?: boolean;
  @ApiPropertyOptional() @IsOptional() @IsNumber() @Min(0) @Max(1) reviewConfidence?: number;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() allowVoice?: boolean;
}

/** Submit: optional final answers (saved first while time remains). */
export class SubmitAnswersDto {
  @ApiPropertyOptional({ type: [AnswerDto] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(100)
  @ValidateNested({ each: true })
  @Type(() => AnswerDto)
  answers?: AnswerDto[];
}

/** Change a test's timing (subject teacher, class teacher of the section, administrators). */
export class RescheduleAiTestDto {
  @ApiPropertyOptional({ nullable: true, description: 'Omit to keep; null = opens on publishing' }) @IsOptional() @IsDateString() startsAt?: string | null;
  @ApiPropertyOptional({ nullable: true, description: 'Omit to keep; null = open until closed' }) @IsOptional() @IsDateString() endsAt?: string | null;
  @ApiProperty({ description: 'Why the test is rescheduled (recorded)' }) @IsString() @MinLength(3) @MaxLength(500) reason: string;
}
