import { Controller, Get, Post, Body, Param, Query, UseGuards } from '@nestjs/common';
import { FeesService } from './fees.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, OFFICE_STAFF } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';
import { CheckoutDto, GenerateInvoiceDto, RecordPaymentDto } from './fees.dto';

@Controller('fees')
@UseGuards(JwtAuthGuard)
export class FeesController {
  constructor(private feesService: FeesService) {}

  @Get('plans')
  async getFeePlans(@CurrentSchoolId() schoolId: string) {
    const data = await this.feesService.getFeePlans(schoolId);
    return { data };
  }

  @Roles(...OFFICE_STAFF, 'PARENT')
  @Get('invoices')
  async getInvoices(
    @CurrentSchoolId() schoolId: string,
    @CurrentUser('userId') userId: string,
    @CurrentUser('role') role: string,
    @Query('studentId') studentId?: string,
  ) {
    const data = await this.feesService.getInvoices(schoolId, { studentId, userId, role });
    return { data };
  }

  @Roles(...OFFICE_STAFF)
  @Post('invoices/generate')
  async generateInvoice(@CurrentSchoolId() schoolId: string, @Body() body: GenerateInvoiceDto) {
    const data = await this.feesService.generateInvoice(schoolId, body);
    return { data };
  }

  /**
   * Records a payment received at the school office (cash, cheque, bank transfer).
   * Online payments must be confirmed by a payment gateway, never by the client.
   */
  @Roles(...OFFICE_STAFF)
  @Post('pay')
  async payInvoice(@CurrentSchoolId() schoolId: string, @CurrentUser() user: any, @Body() body: RecordPaymentDto) {
    const data = await this.feesService.payInvoice(schoolId, { userId: user.userId, name: user.name }, body);
    return { data };
  }
}

@Controller('payments')
@UseGuards(JwtAuthGuard)
export class PaymentsController {
  constructor(private feesService: FeesService) {}

  @Roles(...OFFICE_STAFF, 'PARENT')
  @Post('checkout')
  async checkoutOrder(@CurrentSchoolId() schoolId: string, @CurrentUser() user: any, @Body() body: CheckoutDto) {
    const data = await this.feesService.createCheckoutOrder(schoolId, user, body);
    return { data };
  }

  @Roles(...OFFICE_STAFF, 'PARENT')
  @Get(':id/status')
  async getPaymentStatus(@CurrentSchoolId() schoolId: string, @CurrentUser() user: any, @Param('id') id: string) {
    const data = await this.feesService.getPaymentStatus(schoolId, user, id);
    return { data };
  }
}

@Controller('receipts')
@UseGuards(JwtAuthGuard)
export class ReceiptsController {
  constructor(private feesService: FeesService) {}

  @Roles(...OFFICE_STAFF, 'PARENT')
  @Get(':id')
  async getReceipt(@CurrentSchoolId() schoolId: string, @CurrentUser() user: any, @Param('id') id: string) {
    const data = await this.feesService.getReceiptById(schoolId, user, id);
    return { data };
  }
}
