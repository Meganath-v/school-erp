import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export class GlobalSearchDto {
  @ApiPropertyOptional({ example: 'Sharma', description: 'Search keyword across all 9 domains' })
  @IsOptional()
  @IsString()
  q?: string;

  @ApiPropertyOptional({
    example: 'ALL',
    enum: ['ALL', 'STUDENT', 'STAFF', 'CLASS', 'SUBJECT', 'CIRCULAR', 'ASSIGNMENT', 'INVOICE', 'RECEIPT', 'EXAM'],
  })
  @IsOptional()
  @IsIn(['ALL', 'STUDENT', 'STAFF', 'CLASS', 'SUBJECT', 'CIRCULAR', 'ASSIGNMENT', 'INVOICE', 'RECEIPT', 'EXAM'])
  type?: string = 'ALL';

  @ApiPropertyOptional({ default: 8, minimum: 1, maximum: 50 })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  @IsOptional()
  limit?: number = 8;
}

