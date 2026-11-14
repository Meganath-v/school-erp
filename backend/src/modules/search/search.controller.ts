import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { SearchService } from './search.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentSchoolId } from '../../common/decorators/current-user.decorator';
import { GlobalSearchDto } from './search.dto';

@ApiTags('Unified Omni-Search & Entity Discovery')
@ApiBearerAuth()
@Controller('search')
@UseGuards(JwtAuthGuard)
export class SearchController {
  constructor(private searchService: SearchService) {}

  @Get()
  @ApiOperation({ summary: 'Cross-module search across students, staff, classes, subjects, circulars, assignments, invoices, receipts, and exams' })
  @ApiQuery({ name: 'q', required: false, description: 'Search keyword' })
  @ApiQuery({ name: 'type', required: false, enum: ['ALL', 'STUDENT', 'STAFF', 'CLASS', 'SUBJECT', 'CIRCULAR', 'ASSIGNMENT', 'INVOICE', 'RECEIPT', 'EXAM'] })
  @ApiQuery({ name: 'limit', required: false, description: 'Results limit per entity type' })
  @ApiResponse({ status: 200, description: 'Categorized search results' })
  async search(
    @CurrentSchoolId() schoolId: string,
    @Query() query: GlobalSearchDto,
  ) {
    const data = await this.searchService.search(schoolId, query);
    return { data };
  }
}

