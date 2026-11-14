import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsIn, IsInt, IsNotEmpty, IsNumber, IsOptional, IsPositive, IsString, MaxLength, Min } from 'class-validator';

export const OFFLINE_PAYMENT_METHODS = ['CASH', 'CHEQUE', 'BANK_TRANSFER'];

export class RecordPaymentDto {
  @ApiProperty({ example: 'invoice-uuid-1', description: 'Invoice UUID to record payment against' })
  @IsNotEmpty()
  @IsString()
  invoiceId: string;

  @ApiPropertyOptional({ example: 2500000, description: 'Amount in minor units (paise). Defaults to full outstanding balance.' })
  @IsOptional()
  @IsInt()
  @Min(1)
  amountMinor?: number;

  @ApiPropertyOptional({ example: 25000.00, description: 'Amount in major units (rupees); converted to minor units.' })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  amount?: number;

  @ApiPropertyOptional({ example: 'CASH', enum: OFFLINE_PAYMENT_METHODS })
  @IsOptional()
  @IsIn(OFFLINE_PAYMENT_METHODS)
  method?: string;

  @ApiPropertyOptional({ example: 'Received counter cash payment receipt #504' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  notes?: string;
}

export class GenerateInvoiceDto {
  @ApiProperty({ example: 'student-uuid-1', description: 'Student UUID to bill' })
  @IsNotEmpty()
  @IsString()
  studentId: string;

  @ApiPropertyOptional({ example: 3500000, description: 'Amount in minor units (paise)' })
  @IsOptional()
  @IsInt()
  @Min(1)
  amountMinor?: number;

  @ApiPropertyOptional({ example: 35000.00, description: 'Amount in major units (rupees)' })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  amount?: number;

  @ApiProperty({ example: '2026-12-01', description: 'Due date (ISO 8601)' })
  @IsDateString()
  dueDate: string;

  @ApiPropertyOptional({ example: 'Term 1 Tuition and Laboratory Fee' })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  title?: string;

  @ApiPropertyOptional({ example: 'SCHOOL', enum: ['SCHOOL', 'HOSTEL', 'TRANSPORT'] })
  @IsOptional()
  @IsIn(['SCHOOL', 'HOSTEL', 'TRANSPORT'])
  category?: string;
}

export class CheckoutDto {
  @ApiProperty({ example: 'invoice-uuid-1', description: 'Invoice UUID to initiate gateway checkout for' })
  @IsNotEmpty()
  @IsString()
  invoiceId: string;

  @ApiPropertyOptional({ example: 'RAZORPAY', description: 'Payment gateway provider' })
  @IsOptional()
  @IsString()
  method?: string;
}
