import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsIn, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateCircularDto {
  @ApiProperty({ example: 'Annual Sports Meet 2026 Participation Notice', description: 'Circular title' })
  @IsNotEmpty()
  @IsString()
  title: string;

  @ApiProperty({ example: 'The annual sports meet will be held on December 5th. All students are requested to assemble by 8:00 AM.', description: 'Circular detailed announcement body' })
  @IsNotEmpty()
  @IsString()
  content: string;

  @ApiPropertyOptional({ example: 'ALL', enum: ['ALL', 'ALL_PARENTS', 'ALL_TEACHERS', 'CLASS', 'SECTION'] })
  @IsOptional()
  @IsIn(['ALL', 'ALL_PARENTS', 'ALL_TEACHERS', 'CLASS', 'SECTION'])
  targetAudience?: string;

  @ApiPropertyOptional({ example: 'class-uuid-1', description: 'Class UUID if targeted to a class' })
  @IsOptional()
  @IsString()
  classId?: string;

  @ApiPropertyOptional({ example: 'section-uuid-1', description: 'Section UUID if targeted to a section' })
  @IsOptional()
  @IsString()
  sectionId?: string;

  @ApiPropertyOptional({ example: '/uploads/OAK01/sports_meet_schedule.pdf', description: 'Attachment URL' })
  @IsOptional()
  @IsString()
  fileUrl?: string;

  @ApiPropertyOptional({ example: true, description: 'Whether parents must explicitly acknowledge receipt' })
  @IsOptional()
  @IsBoolean()
  requiresAck?: boolean;
}

export class AcknowledgeCircularDto {
  @ApiPropertyOptional({ example: 'Acknowledged and noted by parents.' })
  @IsOptional()
  @IsString()
  remarks?: string;
}
