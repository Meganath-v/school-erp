import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
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

export const OUTCOME_TYPES = ['PO', 'PSO', 'PEO'] as const;
export const BLOOM_LEVELS = ['REMEMBER', 'UNDERSTAND', 'APPLY', 'ANALYZE', 'EVALUATE', 'CREATE'] as const;
export const QUESTION_TYPES = ['DESCRIPTIVE', 'SHORT_ANSWER', 'MCQ'] as const;
export const ASSESSMENT_TYPES = ['INTERNAL', 'EXTERNAL'] as const;

// ---------------------------------------------------------------- programs

export class CreateProgramDto {
  @ApiProperty({ example: 'BCOM' })
  @IsNotEmpty()
  @IsString()
  @MaxLength(30)
  code: string;

  @ApiProperty({ example: 'Bachelor of Commerce' })
  @IsNotEmpty()
  @IsString()
  @MaxLength(150)
  name: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string;
}

export class UpdateProgramDto {
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(30) code?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(150) name?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(2000) description?: string;
}

export class SetProgramClassesDto {
  @ApiProperty({ type: [String], description: 'Classes that belong to this program (replaces the current list)' })
  @IsArray()
  @ArrayMaxSize(200)
  @IsString({ each: true })
  classIds: string[];
}

export class CreateProgramOutcomeDto {
  @ApiProperty({ enum: OUTCOME_TYPES })
  @IsIn(OUTCOME_TYPES as unknown as string[])
  type: string;

  @ApiProperty({ example: 'PO1' })
  @IsNotEmpty()
  @IsString()
  @MaxLength(20)
  code: string;

  @ApiPropertyOptional({ example: 'Engineering knowledge' })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  title?: string;

  @ApiProperty()
  @IsNotEmpty()
  @IsString()
  @MaxLength(2000)
  description: string;

  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) orderIndex?: number;
}

export class UpdateProgramOutcomeDto {
  @ApiPropertyOptional({ enum: OUTCOME_TYPES }) @IsOptional() @IsIn(OUTCOME_TYPES as unknown as string[]) type?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(20) code?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(150) title?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(2000) description?: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) orderIndex?: number;
}

// ---------------------------------------------------------------- course outcomes

export class CreateOutcomeForSubjectDto {
  @ApiProperty({ example: 'CO1' }) @IsNotEmpty() @IsString() @MaxLength(20) code: string;
  @ApiProperty() @IsNotEmpty() @IsString() @MaxLength(2000) description: string;
  @ApiProperty({ enum: BLOOM_LEVELS }) @IsIn(BLOOM_LEVELS as unknown as string[]) bloomLevel: string;
  @ApiPropertyOptional({ example: 70 }) @IsOptional() @IsInt() @Min(0) @Max(100) targetAttainment?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) orderIndex?: number;
}

export class UpdateCourseOutcomeDto {
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(20) code?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(2000) description?: string;
  @ApiPropertyOptional({ enum: BLOOM_LEVELS }) @IsOptional() @IsIn(BLOOM_LEVELS as unknown as string[]) bloomLevel?: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) @Max(100) targetAttainment?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) orderIndex?: number;
}

export class MappingEntryDto {
  @ApiProperty() @IsString() courseOutcomeId: string;
  @ApiProperty() @IsString() programOutcomeId: string;
  @ApiProperty({ description: '0 removes the link; 1 = low, 2 = medium, 3 = high' })
  @IsInt()
  @Min(0)
  @Max(3)
  strength: number;
}

export class SaveMappingDto {
  @ApiProperty({ type: [MappingEntryDto] })
  @IsArray()
  @ArrayMaxSize(2000)
  @ValidateNested({ each: true })
  @Type(() => MappingEntryDto)
  entries: MappingEntryDto[];
}

export class IndirectEntryDto {
  @ApiProperty() @IsString() courseOutcomeId: string;
  @ApiPropertyOptional({ description: 'Course exit survey level 0-3; null clears it', nullable: true })
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(3)
  level: number | null;
}

export class SaveIndirectDto {
  @ApiProperty({ type: [IndirectEntryDto] })
  @IsArray()
  @ArrayMaxSize(200)
  @ValidateNested({ each: true })
  @Type(() => IndirectEntryDto)
  entries: IndirectEntryDto[];
}

// ---------------------------------------------------------------- attainment rule

export class SaveAttainmentRuleDto {
  @ApiProperty() @IsNumber() @Min(0) @Max(100) studentTargetPercent: number;
  @ApiProperty() @IsNumber() @Min(0) @Max(100) level1Percent: number;
  @ApiProperty() @IsNumber() @Min(0) @Max(100) level2Percent: number;
  @ApiProperty() @IsNumber() @Min(0) @Max(100) level3Percent: number;
  @ApiProperty() @IsNumber() @Min(0) internalWeight: number;
  @ApiProperty() @IsNumber() @Min(0) externalWeight: number;
  @ApiProperty() @IsNumber() @Min(0) directWeight: number;
  @ApiProperty() @IsNumber() @Min(0) indirectWeight: number;
  @ApiProperty() @IsNumber() @Min(0) @Max(3) targetLevel: number;
}

// ---------------------------------------------------------------- question bank

export class CreateQuestionDto {
  @ApiProperty() @IsNotEmpty() @IsString() @MaxLength(5000) text: string;
  @ApiProperty({ example: 5 }) @IsNumber() @Min(0.25) @Max(1000) marks: number;
  @ApiProperty({ enum: BLOOM_LEVELS }) @IsIn(BLOOM_LEVELS as unknown as string[]) bloomLevel: string;
  @ApiPropertyOptional({ nullable: true }) @IsOptional() @IsString() courseOutcomeId?: string | null;
  @ApiPropertyOptional({ enum: QUESTION_TYPES }) @IsOptional() @IsIn(QUESTION_TYPES as unknown as string[]) type?: string;
  @ApiPropertyOptional({ type: [String], description: 'MCQ options (2-6)' })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(6)
  @IsString({ each: true })
  @MaxLength(500, { each: true })
  options?: string[] | null;
  @ApiPropertyOptional({ description: 'MCQ: index of the correct option' }) @IsOptional() @IsInt() @Min(0) @Max(5) correctOption?: number | null;
}

export class UpdateQuestionDto {
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(5000) text?: string;
  @ApiPropertyOptional() @IsOptional() @IsNumber() @Min(0.25) @Max(1000) marks?: number;
  @ApiPropertyOptional({ enum: BLOOM_LEVELS }) @IsOptional() @IsIn(BLOOM_LEVELS as unknown as string[]) bloomLevel?: string;
  @ApiPropertyOptional({ nullable: true }) @IsOptional() @IsString() courseOutcomeId?: string | null;
  @ApiPropertyOptional({ enum: QUESTION_TYPES }) @IsOptional() @IsIn(QUESTION_TYPES as unknown as string[]) type?: string;
  @ApiPropertyOptional({ type: [String], description: 'MCQ options (2-6)' })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(6)
  @IsString({ each: true })
  @MaxLength(500, { each: true })
  options?: string[] | null;
  @ApiPropertyOptional({ description: 'MCQ: index of the correct option' }) @IsOptional() @IsInt() @Min(0) @Max(5) correctOption?: number | null;
}

// ---------------------------------------------------------------- question papers

export class PaperItemDto {
  @ApiProperty() @IsString() questionId: string;
  @ApiProperty({ example: '1a' }) @IsNotEmpty() @IsString() @MaxLength(20) label: string;
  @ApiPropertyOptional({ description: 'Defaults to the question bank marks' })
  @IsOptional()
  @IsNumber()
  @Min(0.25)
  @Max(1000)
  marks?: number;
}

export class PaperSectionDto {
  @ApiProperty({ example: 'Part A' }) @IsNotEmpty() @IsString() @MaxLength(100) title: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(1000) instructions?: string;
  @ApiProperty({ type: [PaperItemDto] })
  @IsArray()
  @ArrayMaxSize(200)
  @ValidateNested({ each: true })
  @Type(() => PaperItemDto)
  items: PaperItemDto[];
}

export class SavePaperDto {
  @ApiProperty() @IsNotEmpty() @IsString() @MaxLength(200) title: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) @Max(1440) durationMinutes?: number;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(2000) instructions?: string;
  @ApiProperty({ type: [PaperSectionDto] })
  @IsArray()
  @ArrayMaxSize(20)
  @ValidateNested({ each: true })
  @Type(() => PaperSectionDto)
  sections: PaperSectionDto[];
}

export class QuestionMarkEntryDto {
  @ApiProperty() @IsString() studentId: string;
  @ApiProperty() @IsString() itemId: string;
  @ApiPropertyOptional({ description: 'null clears the entry', nullable: true })
  @IsOptional()
  @IsNumber()
  @Min(0)
  marks: number | null;
}

export class SaveQuestionMarksDto {
  @ApiProperty({ type: [QuestionMarkEntryDto] })
  @IsArray()
  @ArrayMaxSize(20000)
  @ValidateNested({ each: true })
  @Type(() => QuestionMarkEntryDto)
  entries: QuestionMarkEntryDto[];
}

export class SetAssessmentTypeDto {
  @ApiProperty({ enum: ASSESSMENT_TYPES })
  @IsIn(ASSESSMENT_TYPES as unknown as string[])
  assessmentType: string;
}
