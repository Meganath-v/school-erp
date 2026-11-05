import { Controller, Get, Post, Body, Param, Query, UseGuards } from '@nestjs/common';
import { FeesService } from './fees.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('fees')
@UseGuards(JwtAuthGuard)
export class FeesController {
  constructor(private feesService: FeesService) {}

  @Get('plans')
  async getFeePlans(@CurrentSchoolId() schoolId: string) {
    const data = await this.feesService.getFeePlans(schoolId);
    return { data };
  }

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

  @Post('invoices/generate')
  async generateInvoice(@CurrentSchoolId() schoolId: string, @Body() body: any) {
    const data = await this.feesService.generateInvoice(schoolId, body);
    return { data };
  }

  @Post('pay')
  async payInvoice(@CurrentSchoolId() schoolId: string, @Body() body: any) {
    const data = await this.feesService.payInvoice(schoolId, body);
    return { data };
  }
}

@Controller('payments')
@UseGuards(JwtAuthGuard)
export class PaymentsController {
  constructor(private feesService: FeesService) {}

  @Post('checkout')
  async checkoutOrder(@CurrentSchoolId() schoolId: string, @Body() body: any) {
    const data = await this.feesService.createCheckoutOrder(schoolId, body);
    return { data };
  }

  @Get(':id/status')
  async getPaymentStatus(@CurrentSchoolId() schoolId: string, @Param('id') id: string) {
    const data = await this.feesService.getPaymentStatus(schoolId, id);
    return { data };
  }
}

@Controller('receipts')
@UseGuards(JwtAuthGuard)
export class ReceiptsController {
  constructor(private feesService: FeesService) {}

  @Get(':id')
  async getReceipt(@CurrentSchoolId() schoolId: string, @Param('id') id: string) {
    const data = await this.feesService.getReceiptById(schoolId, id);
    return { data };
  }
}
