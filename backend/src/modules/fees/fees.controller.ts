import { Controller, Get, Post, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiParam, ApiQuery } from '@nestjs/swagger';
import { FeesService } from './fees.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles, OFFICE_STAFF } from '../../common/decorators/roles.decorator';
import { CurrentSchoolId, CurrentUser } from '../../common/decorators/current-user.decorator';
import { CheckoutDto, GenerateInvoiceDto, RecordPaymentDto } from './fees.dto';

@ApiTags('Fee Collections & Billing')
@ApiBearerAuth()
@Controller('fees')
@UseGuards(JwtAuthGuard)
export class FeesController {
  constructor(private feesService: FeesService) {}

  @Get('plans')
  @ApiOperation({ summary: 'List institutional fee plans and fee heads' })
  @ApiResponse({ status: 200, description: 'Fee plans and heads' })
  async getFeePlans(@CurrentSchoolId() schoolId: string) {
    const data = await this.feesService.getFeePlans(schoolId);
    return { data };
  }

  @Roles(...OFFICE_STAFF, 'PARENT')
  @Get('invoices')
  @ApiOperation({ summary: 'List invoices filtered by student or linked parent wards' })
  @ApiQuery({ name: 'studentId', required: false, description: 'Student UUID' })
  @ApiResponse({ status: 200, description: 'Invoices list' })
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
  @ApiOperation({ summary: 'Generate a new tuition/institutional fee invoice' })
  @ApiResponse({ status: 201, description: 'Invoice generated successfully' })
  async generateInvoice(@CurrentSchoolId() schoolId: string, @Body() body: GenerateInvoiceDto) {
    const data = await this.feesService.generateInvoice(schoolId, body);
    return { data };
  }

  @Roles(...OFFICE_STAFF)
  @Post('pay')
  @ApiOperation({ summary: 'Record offline counter fee payment (cash, cheque, bank transfer) atomically' })
  @ApiResponse({ status: 201, description: 'Payment recorded and receipt created' })
  async payInvoice(@CurrentSchoolId() schoolId: string, @CurrentUser() user: any, @Body() body: RecordPaymentDto) {
    const data = await this.feesService.payInvoice(schoolId, { userId: user.userId, name: user.name }, body);
    return { data };
  }
}

@ApiTags('Fee Collections & Billing')
@ApiBearerAuth()
@Controller('payments')
@UseGuards(JwtAuthGuard)
export class PaymentsController {
  constructor(private feesService: FeesService) {}

  @Roles(...OFFICE_STAFF, 'PARENT')
  @Post('checkout')
  @ApiOperation({ summary: 'Initialize online payment gateway order for an invoice' })
  @ApiResponse({ status: 201, description: 'Gateway order session created' })
  async checkoutOrder(@CurrentSchoolId() schoolId: string, @CurrentUser() user: any, @Body() body: CheckoutDto) {
    const data = await this.feesService.createCheckoutOrder(schoolId, user, body);
    return { data };
  }

  @Roles(...OFFICE_STAFF, 'PARENT')
  @Get(':id/status')
  @ApiOperation({ summary: 'Check status of an online payment order' })
  @ApiParam({ name: 'id', description: 'Payment UUID' })
  @ApiResponse({ status: 200, description: 'Payment status' })
  async getPaymentStatus(@CurrentSchoolId() schoolId: string, @CurrentUser() user: any, @Param('id') id: string) {
    const data = await this.feesService.getPaymentStatus(schoolId, user, id);
    return { data };
  }
}

@ApiTags('Fee Collections & Billing')
@ApiBearerAuth()
@Controller('receipts')
@UseGuards(JwtAuthGuard)
export class ReceiptsController {
  constructor(private feesService: FeesService) {}

  @Roles(...OFFICE_STAFF, 'PARENT')
  @Get(':id')
  @ApiOperation({ summary: 'Get payment receipt details for printing or download' })
  @ApiParam({ name: 'id', description: 'Receipt UUID' })
  @ApiResponse({ status: 200, description: 'Payment receipt record' })
  async getReceipt(@CurrentSchoolId() schoolId: string, @CurrentUser() user: any, @Param('id') id: string) {
    const data = await this.feesService.getReceiptById(schoolId, user, id);
    return { data };
  }
}
