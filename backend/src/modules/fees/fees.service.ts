import { Injectable, BadRequestException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { assertStudentAccess, getLinkedStudentIds } from '../../common/access/student-access';
import { RecordPaymentDto, GenerateInvoiceDto, CheckoutDto } from './fees.dto';

type Caller = { userId: string; role: string; name?: string };

function toMinor(amountMinor?: number, amount?: number): number | undefined {
  if (amountMinor !== undefined && amountMinor !== null) return amountMinor;
  if (amount !== undefined && amount !== null) return Math.round(amount * 100);
  return undefined;
}

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

    if (query.role === 'PARENT') {
      const studentIds = await getLinkedStudentIds(this.prisma, schoolId, query.userId);
      if (studentIds.length === 0) return [];
      where.studentId = query.studentId
        ? { in: studentIds.filter((id) => id === query.studentId) }
        : { in: studentIds };
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

  async generateInvoice(schoolId: string, data: GenerateInvoiceDto) {
    const student = await this.prisma.student.findFirst({ where: { id: data.studentId, schoolId } });
    if (!student) {
      throw new BadRequestException('Student not found in this school');
    }
    const amountMinor = toMinor(data.amountMinor, data.amount);
    if (!amountMinor || amountMinor <= 0) {
      throw new BadRequestException('Invoice amount must be greater than zero');
    }
    const count = await this.prisma.invoice.count({ where: { schoolId } });
    const invoiceNo = `INV-${new Date().getFullYear()}-${String(count + 1).padStart(3, '0')}`;

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

  async createCheckoutOrder(schoolId: string, user: Caller, data: CheckoutDto) {
    const invoice = await this.prisma.invoice.findFirst({
      where: { id: data.invoiceId, schoolId },
      include: { student: true, school: true },
    });

    if (!invoice) {
      throw new BadRequestException('Invoice not found (FEE-02)');
    }
    await assertStudentAccess(this.prisma, schoolId, user, invoice.studentId);

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

  async getPaymentStatus(schoolId: string, user: Caller, paymentId: string) {
    const payment = await this.prisma.payment.findFirst({
      where: { id: paymentId, schoolId },
      include: { invoice: true },
    });

    if (!payment) {
      throw new BadRequestException('Payment not found');
    }
    await assertStudentAccess(this.prisma, schoolId, user, payment.invoice.studentId);

    return {
      paymentId: payment.id,
      receiptNo: payment.receiptNo,
      status: payment.status,
      amount: payment.amountMinor / 100,
      invoiceStatus: payment.invoice.status,
      paidAt: payment.createdAt,
    };
  }

  async getReceiptById(schoolId: string, user: Caller, receiptQuery: string) {
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
    await assertStudentAccess(this.prisma, schoolId, user, payment.invoice.studentId);

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

  async payInvoice(schoolId: string, actor: { userId: string; name?: string }, data: RecordPaymentDto) {
    const invoice = await this.prisma.invoice.findFirst({
      where: { id: data.invoiceId, schoolId },
    });

    if (!invoice) {
      throw new BadRequestException('Invoice not found');
    }
    if (invoice.status === 'CANCELLED') {
      throw new BadRequestException('Invoice is cancelled');
    }
    if (invoice.dueAmountMinor <= 0 || invoice.status === 'PAID') {
      throw new BadRequestException('Invoice is already settled in full');
    }

    const payAmountMinor = toMinor(data.amountMinor, data.amount) ?? invoice.dueAmountMinor;
    if (!Number.isInteger(payAmountMinor) || payAmountMinor <= 0) {
      throw new BadRequestException('Payment amount must be a positive amount');
    }
    if (payAmountMinor > invoice.dueAmountMinor) {
      throw new BadRequestException(
        `Payment amount (${payAmountMinor / 100}) exceeds the outstanding balance (${invoice.dueAmountMinor / 100})`,
      );
    }

    const newPaidAmountMinor = invoice.paidAmountMinor + payAmountMinor;
    const newDueAmountMinor = invoice.amountMinor - newPaidAmountMinor;
    const newStatus = newDueAmountMinor === 0 ? 'PAID' : 'PARTIAL';
    const method = data.method || 'CASH';

    return this.prisma.$transaction(async (tx) => {
      // Optimistic concurrency: only apply if nobody else recorded a payment in the meantime.
      const applied = await tx.invoice.updateMany({
        where: { id: invoice.id, schoolId, paidAmountMinor: invoice.paidAmountMinor },
        data: {
          paidAmountMinor: newPaidAmountMinor,
          dueAmountMinor: newDueAmountMinor,
          status: newStatus,
        },
      });
      if (applied.count !== 1) {
        throw new ConflictException('Invoice was updated by another payment. Reload and try again.');
      }

      const count = await tx.payment.count({ where: { schoolId } });
      const receiptNo = `REC-${new Date().getFullYear()}-${String(count + 1).padStart(5, '0')}`;

      const payment = await tx.payment.create({
        data: {
          schoolId,
          invoiceId: invoice.id,
          amountMinor: payAmountMinor,
          method,
          status: 'SUCCESS',
          transactionRef: `OFFICE_${Date.now()}`,
          receiptNo,
          notes: data.notes || `Recorded at office (${method})`,
        },
      });

      const updatedInvoice = await tx.invoice.findUnique({ where: { id: invoice.id } });

      await tx.auditLog.create({
        data: {
          schoolId,
          actorId: actor.userId,
          actorName: actor.name || 'Office Staff',
          action: 'INVOICE_PAYMENT_RECORDED',
          entity: 'Invoice',
          entityId: invoice.id,
          details: JSON.stringify({ receiptNo, amountPaid: payAmountMinor / 100, method, status: newStatus }),
        },
      });

      return {
        message: 'Payment recorded successfully',
        receiptNo,
        invoice: updatedInvoice,
        payment,
      };
    });
  }
}
