import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsIn, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateTaskDto {
  @ApiProperty({ example: 'Complete Term 1 Final Marks Verification', description: 'Task title' })
  @IsNotEmpty()
  @IsString()
  title: string;

  @ApiPropertyOptional({ example: 'Verify internal assessment marks for Section A Mathematics' })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional({ example: 'user-uuid-1', description: 'Assigned User UUID. Defaults to creator if omitted.' })
  @IsOptional()
  @IsString()
  assignedToId?: string;

  @ApiPropertyOptional({ example: 'ACADEMIC', enum: ['ACADEMIC', 'ADMINISTRATIVE', 'FEE_COLLECTION', 'GENERAL'] })
  @IsOptional()
  @IsIn(['ACADEMIC', 'ADMINISTRATIVE', 'FEE_COLLECTION', 'GENERAL'])
  category?: string;

  @ApiPropertyOptional({ example: 'HIGH', enum: ['LOW', 'NORMAL', 'HIGH', 'URGENT'] })
  @IsOptional()
  @IsIn(['LOW', 'NORMAL', 'HIGH', 'URGENT'])
  priority?: string;

  @ApiPropertyOptional({ example: '2026-11-28T18:00:00.000Z' })
  @IsOptional()
  @IsDateString()
  dueDate?: string;

  @ApiPropertyOptional({ example: '/teacher/marks/review' })
  @IsOptional()
  @IsString()
  actionUrl?: string;
}

export class UpdateTaskStatusDto {
  @ApiProperty({ example: 'COMPLETED', enum: ['PENDING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'] })
  @IsIn(['PENDING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'])
  status: string;
}
