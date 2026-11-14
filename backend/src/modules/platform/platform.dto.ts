import { IsEmail, IsNotEmpty, IsOptional, IsString } from 'class-validator';
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
