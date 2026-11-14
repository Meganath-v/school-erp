import { Controller, Post, Get, Body, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { AuthService } from './auth.service';
import {
  LoginDto,
  SwitchSchoolDto,
  RefreshTokenDto,
  ChangePasswordDto,
  ForgotPasswordDto,
  ResetPasswordDto,
} from './auth.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser, CurrentSchoolId } from '../../common/decorators/current-user.decorator';
import { AllowNoMembership } from '../../common/decorators/roles.decorator';
import { Throttle } from '@nestjs/throttler';

@ApiTags('Authentication & Identity')
@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Throttle({ default: { limit: 120, ttl: 60_000 } })
  @ApiOperation({ summary: 'Sign in with credentials and receive access and refresh JWTs' })
  @ApiResponse({ status: 200, description: 'Authentication successful with tokens and user profile' })
  @ApiResponse({ status: 401, description: 'Invalid credentials or inactive membership' })
  @Post('login')
  async login(@Body() dto: LoginDto) {
    const result = await this.authService.login(dto);
    return { data: result };
  }

  @Throttle({ default: { limit: 120, ttl: 60_000 } })
  @ApiOperation({ summary: 'Exchange refresh token for a new access token' })
  @ApiResponse({ status: 200, description: 'Token refreshed successfully' })
  @ApiResponse({ status: 401, description: 'Refresh token expired or invalid' })
  @Post('refresh')
  async refresh(@Body() dto: RefreshTokenDto) {
    const result = await this.authService.refreshToken(dto);
    return { data: result };
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Revoke active session token on logout' })
  @ApiResponse({ status: 200, description: 'Logged out successfully' })
  @Post('logout')
  @UseGuards(JwtAuthGuard)
  @AllowNoMembership()
  async logout(@CurrentUser('userId') userId: string) {
    const result = await this.authService.logout(userId);
    return { data: result };
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Explicitly revoke all active sessions across all devices' })
  @ApiResponse({ status: 200, description: 'All active sessions revoked' })
  @Post('revoke-sessions')
  @UseGuards(JwtAuthGuard)
  @AllowNoMembership()
  async revokeSessions(@CurrentUser('userId') userId: string) {
    const result = await this.authService.revokeAllSessions(userId);
    return { data: result };
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Change account password and revoke all other active sessions' })
  @ApiResponse({ status: 200, description: 'Password changed successfully' })
  @ApiResponse({ status: 400, description: 'Current password incorrect' })
  @Post('change-password')
  @UseGuards(JwtAuthGuard)
  @AllowNoMembership()
  async changePassword(
    @CurrentUser('userId') userId: string,
    @CurrentSchoolId() schoolId: string,
    @Body() dto: ChangePasswordDto,
  ) {
    const result = await this.authService.changePassword(userId, schoolId, dto);
    return { data: result };
  }

  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @ApiOperation({ summary: 'Request password reset token via registered email address' })
  @ApiResponse({ status: 200, description: 'Reset token dispatched' })
  @Post('forgot-password')
  async forgotPassword(@Body() dto: ForgotPasswordDto) {
    const result = await this.authService.forgotPassword(dto);
    return { data: result };
  }

  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @ApiOperation({ summary: 'Reset account password using single-use verification token' })
  @ApiResponse({ status: 200, description: 'Password reset completed and all sessions revoked' })
  @ApiResponse({ status: 400, description: 'Invalid or expired token' })
  @Post('reset-password')
  async resetPassword(@Body() dto: ResetPasswordDto) {
    const result = await this.authService.resetPassword(dto);
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
