import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsDateString, IsIn, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateAnnouncementDto {
  @ApiProperty({ example: 'Winter Vacation Schedule 2026', description: 'Announcement title' })
  @IsNotEmpty()
  @IsString()
  title: string;

  @ApiProperty({ example: 'The school will remain closed for winter vacation from Dec 24 to Jan 2.', description: 'Announcement body' })
  @IsNotEmpty()
  @IsString()
  content: string;

  @ApiPropertyOptional({ example: 'ALL', enum: ['ALL', 'TEACHERS', 'PARENTS', 'STUDENTS'] })
  @IsOptional()
  @IsIn(['ALL', 'TEACHERS', 'PARENTS', 'STUDENTS'])
  targetRole?: string;

  @ApiPropertyOptional({ example: 'NORMAL', enum: ['LOW', 'NORMAL', 'HIGH', 'URGENT'] })
  @IsOptional()
  @IsIn(['LOW', 'NORMAL', 'HIGH', 'URGENT'])
  priority?: string;

  @ApiPropertyOptional({ example: true, description: 'True if broadcast to whole school' })
  @IsOptional()
  @IsBoolean()
  isSchoolWide?: boolean;

  @ApiPropertyOptional({ example: 'Principal Office' })
  @IsOptional()
  @IsString()
  authorName?: string;

  @ApiPropertyOptional({ example: '2026-11-14T00:00:00Z', description: 'Start date' })
  @IsOptional()
  @IsDateString()
  startsAt?: string;

  @ApiPropertyOptional({ example: '2026-12-31T23:59:59Z', description: 'Expiration date' })
  @IsOptional()
  @IsDateString()
  expiresAt?: string;

  @ApiPropertyOptional({ example: 'https://example.com/notices/circular12.pdf' })
  @IsOptional()
  @IsString()
  attachments?: string;
}

