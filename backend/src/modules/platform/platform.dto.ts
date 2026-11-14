import { IsEmail, IsIn, IsInt, IsNotEmpty, IsOptional, IsPositive, IsString } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateSchoolDto {
  @ApiProperty({ example: 'Cambridge International School' })
  @IsNotEmpty()
  @IsString()
  name: string;

  @ApiProperty({ example: 'CAM03' })
  @IsNotEmpty()
  @IsString()
  code: string;

  @ApiProperty({ example: 'cambridge' })
  @IsNotEmpty()
  @IsString()
  slug: string;

  @ApiPropertyOptional({ example: '77 Residency Road, Bangalore' })
  @IsOptional()
  @IsString()
  address?: string;

  @ApiPropertyOptional({ example: 'admin@cambridge.edu' })
  @IsOptional()
  @IsString()
  contactEmail?: string;

  @ApiPropertyOptional({ example: '+91 80 5555 4444' })
  @IsOptional()
  @IsString()
  contactPhone?: string;

  @ApiProperty({ example: 'admin@cambridge.edu' })
  @IsNotEmpty()
  @IsEmail()
  adminEmail: string;

  @ApiProperty({ example: 'Charles' })
  @IsNotEmpty()
  @IsString()
  adminFirstName: string;

  @ApiProperty({ example: 'Darwin' })
  @IsNotEmpty()
  @IsString()
  adminLastName: string;

  @ApiPropertyOptional({ example: 'GROWTH', default: 'GROWTH' })
  @IsOptional()
  @IsString()
  planCode?: string;
}

export class UpdateSchoolStatusDto {
  @ApiProperty({ example: 'SUSPENDED', enum: ['ACTIVE', 'SUSPENDED', 'TRIAL'] })
  @IsIn(['ACTIVE', 'SUSPENDED', 'TRIAL'])
  status: 'ACTIVE' | 'SUSPENDED' | 'TRIAL';
}

export class CreateSubscriptionPlanDto {
  @ApiProperty({ example: 'ENTERPRISE', description: 'Unique plan code' })
  @IsNotEmpty()
  @IsString()
  code: string;

  @ApiProperty({ example: 'Enterprise Multi-Campus Plan' })
  @IsNotEmpty()
  @IsString()
  name: string;

  @ApiPropertyOptional({ example: 4999900, description: 'Price in minor currency units (e.g. paise)' })
  @IsOptional()
  @IsInt()
  @IsPositive()
  priceMinor?: number;

  @ApiPropertyOptional({ example: 'INR', default: 'INR' })
  @IsOptional()
  @IsString()
  currency?: string;

  @ApiPropertyOptional({ example: 'YEARLY', enum: ['MONTHLY', 'YEARLY'], default: 'YEARLY' })
  @IsOptional()
  @IsIn(['MONTHLY', 'YEARLY'])
  billingInterval?: string;

  @ApiPropertyOptional({ example: 2500, default: 500 })
  @IsOptional()
  @IsInt()
  @IsPositive()
  studentLimit?: number;

  @ApiPropertyOptional({ example: 250, default: 50 })
  @IsOptional()
  @IsInt()
  @IsPositive()
  staffLimit?: number;

  @ApiPropertyOptional({ example: 30, default: 30 })
  @IsOptional()
  @IsInt()
  trialDays?: number;
}
