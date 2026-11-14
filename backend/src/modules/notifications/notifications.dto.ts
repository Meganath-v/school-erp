import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsOptional } from 'class-validator';

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
