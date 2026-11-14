import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsIn, IsNotEmpty, IsOptional, IsString } from 'class-validator';

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
}

