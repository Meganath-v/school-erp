import { Controller, Post, Get, Body, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { LoginDto, SwitchSchoolDto, RefreshTokenDto } from './auth.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser, CurrentSchoolId } from '../../common/decorators/current-user.decorator';
import { AllowNoMembership } from '../../common/decorators/roles.decorator';
import { Throttle } from '@nestjs/throttler';

@ApiTags('Authentication & Identity')
@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @ApiOperation({ summary: 'Sign in with credentials and receive access and refresh JWTs' })
  @ApiResponse({ status: 200, description: 'Authentication successful with tokens and user profile' })
  @ApiResponse({ status: 401, description: 'Invalid credentials or inactive membership' })
  @Post('login')
  async login(@Body() dto: LoginDto) {
    const result = await this.authService.login(dto);
    return { data: result };
  }

  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @ApiOperation({ summary: 'Exchange refresh token for a new access token' })
  @ApiResponse({ status: 200, description: 'Token refreshed successfully' })
  @ApiResponse({ status: 401, description: 'Refresh token expired or invalid' })
  @Post('refresh')
  async refresh(@Body() dto: RefreshTokenDto) {
    const result = await this.authService.refreshToken(dto);
    return { data: result };
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Revoke active session token' })
  @ApiResponse({ status: 200, description: 'Logged out successfully' })
  @Post('logout')
  @UseGuards(JwtAuthGuard)
  @AllowNoMembership()
  async logout(@CurrentUser('userId') userId: string) {
    const result = await this.authService.logout(userId);
    return { data: result };
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get current authenticated user profile, active school, and roles' })
  @ApiResponse({ status: 200, description: 'User profile retrieved' })
  @Get('me')
  @UseGuards(JwtAuthGuard)
  @AllowNoMembership()
  async getMe(@CurrentUser('userId') userId: string, @CurrentSchoolId() schoolId: string) {
    const result = await this.authService.getMe(userId, schoolId);
    return { data: result };
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Switch active school context for multi-tenant accounts' })
  @ApiResponse({ status: 200, description: 'Active school context switched' })
  @Post('switch-school')
  @UseGuards(JwtAuthGuard)
  @AllowNoMembership()
  async switchSchool(@CurrentUser('userId') userId: string, @Body() dto: SwitchSchoolDto) {
    const result = await this.authService.switchSchool(userId, dto);
    return { data: result };
  }
}
