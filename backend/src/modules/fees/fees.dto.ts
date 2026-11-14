import { IsDateString, IsIn, IsInt, IsNotEmpty, IsNumber, IsOptional, IsPositive, IsString, MaxLength, Min } from 'class-validator';

export const OFFLINE_PAYMENT_METHODS = ['CASH', 'CHEQUE', 'BANK_TRANSFER'];

export class RecordPaymentDto {
  @IsNotEmpty()
  @IsString()
  invoiceId: string;

  /** Amount in minor units (paise). Defaults to the full outstanding amount. */
  @IsOptional()
  @IsInt()
  @Min(1)
  amountMinor?: number;

  /** Amount in major units (rupees); converted to minor units. Ignored when amountMinor is sent. */
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  amount?: number;

  @IsOptional()
  @IsIn(OFFLINE_PAYMENT_METHODS)
  method?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  notes?: string;
}

export class GenerateInvoiceDto {
  @IsNotEmpty()
  @IsString()
  studentId: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  amountMinor?: number;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  amount?: number;

  @IsDateString()
  dueDate: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  title?: string;

  @IsOptional()
  @IsIn(['SCHOOL', 'HOSTEL', 'TRANSPORT'])
  category?: string;
}

export class CheckoutDto {
  @IsNotEmpty()
  @IsString()
  invoiceId: string;

  @IsOptional()
  @IsString()
  method?: string;
}
