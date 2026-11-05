import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class FeesService {
  constructor(private prisma: PrismaService) {}

  async getFeePlans(schoolId: string) {
    const plans = await this.prisma.feePlan.findMany({
      where: { schoolId },
      include: { class: true, academicYear: true },
    });
    const heads = await this.prisma.feeHead.findMany({ where: { schoolId } });
    return { plans, heads };
  }

  async getInvoices(schoolId: string, query: { studentId?: string; role?: string; userId?: string }) {
    const where: any = { schoolId };

    if (query.role === 'PARENT' && query.userId) {
      const guardian = await this.prisma.guardian.findFirst({
        where: { schoolId, userId: query.userId },
        include: { students: true },
      });
      if (!guardian) return [];
      const studentIds = guardian.students.map((s) => s.studentId);
      where.studentId = { in: studentIds };
    } else if (query.studentId) {
      where.studentId = query.studentId;
    }

    const invoices = await this.prisma.invoice.findMany({
      where,
      include: {
        student: {
          include: {
            enrollments: {
              where: { status: 'ACTIVE' },
              include: { class: true, section: true },
            },
          },
        },
        payments: true,
      },
      orderBy: { createdAt: 'desc' },
    });

    return invoices.map((inv) => ({
      id: inv.id,
      invoiceNo: inv.invoiceNo,
      title: inv.title,
      studentId: inv.studentId,
      studentName: `${inv.student.firstName} ${inv.student.lastName}`,
      admissionNo: inv.student.admissionNo,
      className: inv.student.enrollments[0]?.class?.name || 'N/A',
      sectionName: inv.student.enrollments[0]?.section?.name || 'N/A',
      amountMinor: inv.amountMinor,
      amount: inv.amountMinor / 100,
      paidAmountMinor: inv.paidAmountMinor,
      paidAmount: inv.paidAmountMinor / 100,
      dueAmountMinor: inv.dueAmountMinor,
      dueAmount: inv.dueAmountMinor / 100,
      dueDate: inv.dueDate,
      status: inv.status,
      payments: inv.payments.map((p) => ({
        id: p.id,
        amount: p.amountMinor / 100,
        receiptNo: p.receiptNo,
        method: p.method,
        status: p.status,
        date: p.createdAt,
      })),
    }));
  }

  async generateInvoice(schoolId: string, data: any) {
    const count = await this.prisma.invoice.count({ where: { schoolId } });
    const invoiceNo = `INV-2026-${String(count + 1).padStart(3, '0')}`;
    const amountMinor = data.amountMinor || data.amount * 100;

    return this.prisma.invoice.create({
      data: {
        schoolId,
        studentId: data.studentId,
        invoiceNo,
        title: data.title || 'Tuition Fee Demand',
        category: data.category || 'SCHOOL',
        amountMinor,
        paidAmountMinor: 0,
        dueAmountMinor: amountMinor,
        dueDate: new Date(data.dueDate),
        status: 'PENDING',
      },
    });
  }

  async createCheckoutOrder(schoolId: string, data: { invoiceId: string; method?: string }) {
    const invoice = await this.prisma.invoice.findFirst({
      where: { id: data.invoiceId, schoolId },
      include: { student: true, school: true },
    });

    if (!invoice) {
      throw new BadRequestException('Invoice not found (FEE-02)');
    }

    if (invoice.dueAmountMinor <= 0) {
      throw new BadRequestException('Invoice is already settled in full');
    }

    // Server-side calculated checkout amount (FEE-03)
    const payableAmount = invoice.dueAmountMinor / 100;
    const orderId = `ORD_${Date.now()}_${Math.floor(Math.random() * 1000)}`;

    return {
      orderId,
      invoiceId: invoice.id,
      invoiceNo: invoice.invoiceNo,
      category: invoice.category || 'SCHOOL',
      studentName: `${invoice.student.firstName} ${invoice.student.lastName}`,
      serverCalculatedAmount: payableAmount,
      currency: 'INR',
      currencySymbol: '₹',
      status: 'READY_FOR_CHECKOUT',
      gatewayOptions: [
        { id: 'UPI', name: 'Instant UPI (GPay, PhonePe, Paytm)' },
        { id: 'NETBANKING', name: 'Net Banking (All Indian Banks)' },
        { id: 'CARD', name: 'Credit / Debit Card' },
      ],
    };
  }

  async getPaymentStatus(schoolId: string, paymentId: string) {
    const payment = await this.prisma.payment.findFirst({
      where: { id: paymentId, schoolId },
      include: { invoice: true },
    });

    if (!payment) {
      throw new BadRequestException('Payment not found');
    }

    return {
      paymentId: payment.id,
      receiptNo: payment.receiptNo,
      status: payment.status,
      amount: payment.amountMinor / 100,
      invoiceStatus: payment.invoice.status,
      paidAt: payment.createdAt,
    };
  }

  async getReceiptById(schoolId: string, receiptQuery: string) {
    const payment = await this.prisma.payment.findFirst({
      where: {
        schoolId,
        OR: [{ id: receiptQuery }, { receiptNo: receiptQuery }],
      },
      include: {
        invoice: {
          include: {
            student: {
              include: {
                enrollments: {
                  where: { status: 'ACTIVE' },
                  include: { class: true, section: true },
                },
              },
            },
          },
        },
        school: true,
      },
    });

    if (!payment) {
      throw new BadRequestException('Receipt not found');
    }

    const inv = payment.invoice;
    const stu = inv.student;
    const enrollment = stu.enrollments[0];

    return {
      receiptNo: payment.receiptNo,
      issuedAt: payment.createdAt,
      school: {
        id: payment.school.id,
        name: payment.school.name,
        code: payment.school.code,
        address: payment.school.address || 'Campus Road, Education District',
        contactPhone: payment.school.contactPhone || '+91 80 4123 4567',
        contactEmail: payment.school.contactEmail || 'office@schoolerp.com',
      },
      student: {
        id: stu.id,
        name: `${stu.firstName} ${stu.lastName}`,
        admissionNo: stu.admissionNo,
        class: enrollment?.class?.name || 'Grade 10',
        section: enrollment?.section?.name || 'Section A',
      },
      feeDetails: {
        invoiceNo: inv.invoiceNo,
        title: inv.title,
        category: inv.category || 'SCHOOL',
        totalInvoiceAmount: inv.amountMinor / 100,
        amountPaidThisTransaction: payment.amountMinor / 100,
        remainingBalance: inv.dueAmountMinor / 100,
        paymentMethod: payment.method,
        transactionRef: payment.transactionRef,
        status: payment.status,
        digitalSignature: `SIG_${Buffer.from(payment.receiptNo + payment.amountMinor).toString('base64').substring(0, 16)}`,
      },
    };
  }

  async payInvoice(schoolId: string, data: { invoiceId: string; amountMinor?: number; amount?: number; method?: string; notes?: string }) {
    const invoice = await this.prisma.invoice.findFirst({
      where: { id: data.invoiceId, schoolId },
    });

    if (!invoice) {
      throw new BadRequestException('Invoice not found');
    }

    const payAmountMinor = data.amountMinor || (data.amount ? data.amount * 100 : invoice.dueAmountMinor);
    const newPaidAmountMinor = invoice.paidAmountMinor + payAmountMinor;
    const newDueAmountMinor = Math.max(0, invoice.amountMinor - newPaidAmountMinor);
    const newStatus = newDueAmountMinor === 0 ? 'PAID' : 'PARTIAL';

    const count = await this.prisma.payment.count({ where: { schoolId } });
    const receiptNo = `REC-2026-${String(count + 1).padStart(5, '0')}`;

    // Create payment
    const payment = await this.prisma.payment.create({
      data: {
        schoolId,
        invoiceId: invoice.id,
        amountMinor: payAmountMinor,
        method: data.method || 'ONLINE',
        status: 'SUCCESS',
        transactionRef: `TXN_${Date.now()}`,
        receiptNo,
        notes: data.notes || 'Online payment processed',
      },
    });

    // Update invoice
    const updatedInvoice = await this.prisma.invoice.update({
      where: { id: invoice.id },
      data: {
        paidAmountMinor: newPaidAmountMinor,
        dueAmountMinor: newDueAmountMinor,
        status: newStatus,
      },
    });

    // Audit log
    await this.prisma.auditLog.create({
      data: {
        schoolId,
        actorId: 'Parent/Office',
        actorName: 'Payer',
        action: 'INVOICE_PAID',
        entity: 'Invoice',
        entityId: invoice.id,
        details: JSON.stringify({ receiptNo, amountPaid: payAmountMinor / 100, status: newStatus }),
      },
    });

    return {
      message: 'Payment completed successfully',
      receiptNo,
      invoice: updatedInvoice,
      payment,
    };
  }
}
