import { IsEmail, IsNotEmpty, IsOptional, IsString, MinLength } from 'class-validator';

export class LoginDto {
  @IsNotEmpty()
  @IsString()
  login: string; // email or username or phone

  @IsNotEmpty()
  @IsString()
  @MinLength(6)
  password: string;

  @IsOptional()
  @IsString()
  schoolCode?: string; // Optional school code filter or fallback to primary membership
}

export class SwitchSchoolDto {
  @IsNotEmpty()
  @IsString()
  schoolId: string;
}

export class RefreshTokenDto {
  @IsNotEmpty()
  @IsString()
  refreshToken: string;
}
