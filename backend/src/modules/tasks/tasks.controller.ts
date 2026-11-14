import { Controller, Get, Post, Patch, Body, Param, Query, UseGuards } from '@nestjs/common';
import { TasksService } from './tasks.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, ALL_STAFF } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('tasks')
@UseGuards(JwtAuthGuard)
export class TasksController {
  constructor(private tasksService: TasksService) {}

  @Get()
  async getTasks(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @CurrentUser('role') role: string,
    @Query('status') status?: string,
  ) {
    const data = await this.tasksService.getTasks(schoolId, userId, role, status);
    return { data };
  }

  @Get('stats')
  async getStats(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
  ) {
    const data = await this.tasksService.getTaskStats(schoolId, userId);
    return { data };
  }

  @Roles(...ALL_STAFF)
  @Post()
  async createTask(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @Body() body: any,
  ) {
    const data = await this.tasksService.createTask(schoolId, userId, body);
    return { data };
  }

  @Patch(':id/status')
  async updateStatus(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
    @Body('status') status: string,
  ) {
    const data = await this.tasksService.updateTaskStatus(schoolId, userId, id, status);
    return { data };
  }
}

