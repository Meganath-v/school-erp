import { Controller, Post, Get, Body, UseGuards } from '@nestjs/common';
import { AuthService } from './auth.service';
import { LoginDto, SwitchSchoolDto, RefreshTokenDto } from './auth.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser, CurrentSchoolId } from '../../common/decorators/current-user.decorator';
import { AllowNoMembership } from '../../common/decorators/roles.decorator';
import { Throttle } from '@nestjs/throttler';

@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('login')
  async login(@Body() dto: LoginDto) {
    const result = await this.authService.login(dto);
    return { data: result };
  }

  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @Post('refresh')
  async refresh(@Body() dto: RefreshTokenDto) {
    const result = await this.authService.refreshToken(dto);
    return { data: result };
  }

  @Post('logout')
  @UseGuards(JwtAuthGuard)
  @AllowNoMembership()
  async logout(@CurrentUser('userId') userId: string) {
    const result = await this.authService.logout(userId);
    return { data: result };
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  @AllowNoMembership()
  async getMe(@CurrentUser('userId') userId: string, @CurrentSchoolId() schoolId: string) {
    const result = await this.authService.getMe(userId, schoolId);
    return { data: result };
  }

  @Post('switch-school')
  @UseGuards(JwtAuthGuard)
  @AllowNoMembership()
  async switchSchool(@CurrentUser('userId') userId: string, @Body() dto: SwitchSchoolDto) {
    const result = await this.authService.switchSchool(userId, dto);
    return { data: result };
  }
}
