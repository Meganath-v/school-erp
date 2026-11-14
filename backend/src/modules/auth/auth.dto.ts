import { IsEmail, IsNotEmpty, IsOptional, IsString, MinLength } from 'class-validator';
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

export class ChangePasswordDto {
  @ApiProperty({ example: 'currentPassword123', description: 'Current account password' })
  @IsNotEmpty()
  @IsString()
  @MinLength(6)
  oldPassword: string;

  @ApiProperty({ example: 'newSecurePassword456!', description: 'New account password' })
  @IsNotEmpty()
  @IsString()
  @MinLength(6)
  newPassword: string;
}

export class ForgotPasswordDto {
  @ApiProperty({ example: 'teacher@oakridge.edu', description: 'Registered account email address' })
  @IsNotEmpty()
  @IsEmail()
  email: string;

  @ApiPropertyOptional({ example: 'OAK01', description: 'Optional school code context' })
  @IsOptional()
  @IsString()
  schoolCode?: string;
}

export class ResetPasswordDto {
  @ApiProperty({ description: 'Single-use cryptographic reset token received via forgot password request' })
  @IsNotEmpty()
  @IsString()
  token: string;

  @ApiProperty({ example: 'newSecurePassword789!', description: 'New password' })
  @IsNotEmpty()
  @IsString()
  @MinLength(6)
  newPassword: string;
}
