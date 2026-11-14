import { IsNotEmpty, IsOptional, IsString, MinLength } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class LoginDto {
  @ApiProperty({ example: 'admin@oakridge.edu', description: 'Email, username or phone number' })
  @IsNotEmpty()
  @IsString()
  login: string;

  @ApiProperty({ example: 'password123', description: 'User account password' })
  @IsNotEmpty()
  @IsString()
  @MinLength(6)
  password: string;

  @ApiPropertyOptional({ example: 'OAK01', description: 'Unique school code for multi-school tenant scoping' })
  @IsOptional()
  @IsString()
  schoolCode?: string;
}

export class SwitchSchoolDto {
  @ApiProperty({ description: 'Target school identifier to switch active membership' })
  @IsNotEmpty()
  @IsString()
  schoolId: string;
}

export class RefreshTokenDto {
  @ApiProperty({ description: 'Cryptographic refresh token' })
  @IsNotEmpty()
  @IsString()
  refreshToken: string;
}
