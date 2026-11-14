import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsIn, IsNumber, IsOptional, IsString } from 'class-validator';
import { Type } from 'class-transformer';

export class UpdateNotificationPreferencesDto {
  @ApiPropertyOptional({ example: true, description: 'Receive email notifications' })
  @IsOptional()
  @IsBoolean()
  emailEnabled?: boolean;

  @ApiPropertyOptional({ example: true, description: 'Receive SMS notifications' })
  @IsOptional()
  @IsBoolean()
  smsEnabled?: boolean;

  @ApiPropertyOptional({ example: true, description: 'Receive mobile push notifications' })
  @IsOptional()
  @IsBoolean()
  pushEnabled?: boolean;

  @ApiPropertyOptional({ example: true, description: 'Receive student attendance status alerts' })
  @IsOptional()
  @IsBoolean()
  attendanceAlerts?: boolean;

  @ApiPropertyOptional({ example: true, description: 'Receive fee invoice and reminder alerts' })
  @IsOptional()
  @IsBoolean()
  feeAlerts?: boolean;

  @ApiPropertyOptional({ example: true, description: 'Receive exam schedule and result alerts' })
  @IsOptional()
  @IsBoolean()
  examAlerts?: boolean;
}

export class GetNotificationsQueryDto {
  @ApiPropertyOptional({ example: 'ALL', enum: ['ALL', 'UNREAD', 'READ', 'ARCHIVED'] })
  @IsOptional()
  @IsIn(['ALL', 'UNREAD', 'READ', 'ARCHIVED'])
  status?: string;

  @ApiPropertyOptional({ example: 'ALL', enum: ['ALL', 'LOW', 'NORMAL', 'HIGH', 'URGENT'] })
  @IsOptional()
  @IsIn(['ALL', 'LOW', 'NORMAL', 'HIGH', 'URGENT'])
  priority?: string;

  @ApiPropertyOptional({ example: 1, description: 'Page number (default: 1)' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  page?: number;

  @ApiPropertyOptional({ example: 20, description: 'Page size limit (default: 20)' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  limit?: number;

  @ApiPropertyOptional({ example: 'invoice', description: 'Search term for title or body' })
  @IsOptional()
  @IsString()
  search?: string;
}
