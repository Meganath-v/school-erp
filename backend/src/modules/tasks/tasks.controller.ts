import { Controller, Get, Post, Patch, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiParam, ApiQuery } from '@nestjs/swagger';
import { TasksService } from './tasks.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, ALL_STAFF } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';
import { CreateTaskDto, UpdateTaskStatusDto } from './tasks.dto';

@ApiTags('Staff Task Pipeline & Action Items')
@ApiBearerAuth()
@Controller('tasks')
@UseGuards(JwtAuthGuard)
export class TasksController {
  constructor(private tasksService: TasksService) {}

  @Get()
  @ApiOperation({ summary: 'List tasks assigned to or created by caller' })
  @ApiQuery({ name: 'status', required: false })
  @ApiResponse({ status: 200, description: 'List of tasks' })
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
  @ApiOperation({ summary: 'Get summary statistics of pending, completed, and overdue tasks' })
  @ApiResponse({ status: 200, description: 'Task counts' })
  async getStats(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
  ) {
    const data = await this.tasksService.getTaskStats(schoolId, userId);
    return { data };
  }

  @Roles(...ALL_STAFF)
  @Post()
  @ApiOperation({ summary: 'Create and assign a staff action item' })
  @ApiResponse({ status: 201, description: 'Task created' })
  async createTask(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @Body() body: CreateTaskDto,
  ) {
    const data = await this.tasksService.createTask(schoolId, userId, body);
    return { data };
  }

  @Patch(':id/status')
  @ApiOperation({ summary: 'Update workflow status of a task' })
  @ApiParam({ name: 'id', description: 'Task UUID' })
  @ApiResponse({ status: 200, description: 'Task status updated' })
  async updateStatus(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
    @Body() body: UpdateTaskStatusDto,
  ) {
    const data = await this.tasksService.updateTaskStatus(schoolId, userId, id, body.status);
    return { data };
  }
}
