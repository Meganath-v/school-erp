import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsIn, IsInt, IsNotEmpty, IsOptional, IsString, Max, Min } from 'class-validator';

export class SubmitFeedbackDto {
  @ApiProperty({ example: 'Library Book Selection Improvement', description: 'Feedback subject' })
  @IsNotEmpty()
  @IsString()
  title: string;

  @ApiProperty({ example: 'Could we please have more contemporary STEM reference books in the secondary library?', description: 'Detailed feedback' })
  @IsNotEmpty()
  @IsString()
  content: string;

  @ApiPropertyOptional({ example: 'FACILITIES', enum: ['ACADEMICS', 'FACILITIES', 'TRANSPORT', 'CANTEEN', 'GENERAL'] })
  @IsOptional()
  @IsIn(['ACADEMICS', 'FACILITIES', 'TRANSPORT', 'CANTEEN', 'GENERAL'])
  category?: string;

  @ApiPropertyOptional({ example: 'GENERAL', description: 'Target entity type' })
  @IsOptional()
  @IsString()
  targetType?: string;

  @ApiPropertyOptional({ example: 'library-id' })
  @IsOptional()
  @IsString()
  targetId?: string;

  @ApiPropertyOptional({ example: 'Main Campus Library' })
  @IsOptional()
  @IsString()
  targetName?: string;

  @ApiPropertyOptional({ example: 4, description: 'Rating (1 to 5)' })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(5)
  rating?: number;

  @ApiPropertyOptional({ example: false, description: 'True to hide submitter identity' })
  @IsOptional()
  @IsBoolean()
  isAnonymous?: boolean;
}

export class RespondFeedbackDto {
  @ApiProperty({ example: 'Thank you for your valuable suggestion. We have requisitioned 25 new science titles for the library catalog.' })
  @IsNotEmpty()
  @IsString()
  response: string;

  @ApiPropertyOptional({ example: 'RESOLVED', enum: ['UNDER_REVIEW', 'RESOLVED', 'DISMISSED'] })
  @IsOptional()
  @IsIn(['UNDER_REVIEW', 'RESOLVED', 'DISMISSED'])
  status?: string;
}

export class UpdateFeedbackStatusDto {
  @ApiProperty({ example: 'RESOLVED', enum: ['SUBMITTED', 'UNDER_REVIEW', 'RESOLVED', 'DISMISSED'] })
  @IsIn(['SUBMITTED', 'UNDER_REVIEW', 'RESOLVED', 'DISMISSED'])
  status: string;
}
