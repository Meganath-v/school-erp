import { Controller, Post, Get, Body, UseGuards } from '@nestjs/common';
import { AuthService } from './auth.service';
import { LoginDto, SwitchSchoolDto, RefreshTokenDto } from './auth.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser, CurrentSchoolId } from '../../common/decorators/current-user.decorator';

@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Post('login')
  async login(@Body() dto: LoginDto) {
    const result = await this.authService.login(dto);
    return { data: result };
  }

  @Post('refresh')
  async refresh(@Body() dto: RefreshTokenDto) {
    const result = await this.authService.refreshToken(dto);
    return { data: result };
  }

  @Post('logout')
  async logout() {
    return { data: { message: 'Logged out successfully' } };
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  async getMe(@CurrentUser('userId') userId: string, @CurrentSchoolId() schoolId: string) {
    const result = await this.authService.getMe(userId, schoolId);
    return { data: result };
  }

  @Post('switch-school')
  @UseGuards(JwtAuthGuard)
  async switchSchool(@CurrentUser('userId') userId: string, @Body() dto: SwitchSchoolDto) {
    const result = await this.authService.switchSchool(userId, dto);
    return { data: result };
  }
}
