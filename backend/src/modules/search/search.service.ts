import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

export interface SearchResultItem {
  id: string;
  type: 'STUDENT' | 'STAFF' | 'CLASS' | 'SUBJECT' | 'CIRCULAR' | 'ASSIGNMENT' | 'INVOICE' | 'RECEIPT' | 'EXAM';
  title: string;
  subtitle: string;
  status?: string;
  routeTarget: string;
  metadata?: Record<string, any>;
}

@Injectable()
export class SearchService {
  constructor(private prisma: PrismaService) {}

  async search(schoolId: string, query: { q?: string; type?: string; limit?: number }) {
    const q = (query.q || '').trim();
    if (!q) {
      return { query: '', totalMatches: 0, results: [] };
    }

    const type = query.type || 'ALL';
    const limit = query.limit || 8;
    const results: SearchResultItem[] = [];

    const searchAll = type === 'ALL';

    // 1. Students
    if (searchAll || type === 'STUDENT') {
      const students = await this.prisma.student.findMany({
        where: {
          schoolId,
          OR: [
            { firstName: { contains: q, mode: 'insensitive' } },
            { lastName: { contains: q, mode: 'insensitive' } },
            { admissionNo: { contains: q, mode: 'insensitive' } },
          ],
        },
        take: limit,
        include: {
          enrollments: {
            where: { status: 'ACTIVE' },
            include: { class: true, section: true },
          },
        },
      });

      for (const s of students) {
        const enr = s.enrollments[0];
        const classLabel = enr ? `${enr.class.name}-${enr.section.name}` : 'Unassigned';
        results.push({
          id: s.id,
          type: 'STUDENT',
          title: `${s.firstName} ${s.lastName}`,
          subtitle: `Admission No: ${s.admissionNo} • ${classLabel}`,
          status: s.status,
          routeTarget: 'STUDENT_MANAGEMENT',
          metadata: { admissionNo: s.admissionNo, class: classLabel },
        });
      }
    }

    // 2. Staff
    if (searchAll || type === 'STAFF') {
      const staffMembers = await this.prisma.staff.findMany({
        where: {
          schoolId,
          OR: [
            { firstName: { contains: q, mode: 'insensitive' } },
            { lastName: { contains: q, mode: 'insensitive' } },
            { employeeNo: { contains: q, mode: 'insensitive' } },
            { department: { contains: q, mode: 'insensitive' } },
            { email: { contains: q, mode: 'insensitive' } },
            { designation: { contains: q, mode: 'insensitive' } },
          ],
        },
        take: limit,
      });

      for (const st of staffMembers) {
        results.push({
          id: st.id,
          type: 'STAFF',
          title: `${st.firstName} ${st.lastName}`,
          subtitle: `${st.designation} • Dept: ${st.department} (EMP: ${st.employeeNo})`,
          status: st.status,
          routeTarget: 'STAFF_MANAGEMENT',
          metadata: { employeeNo: st.employeeNo, department: st.department },
        });
      }
    }

    // 3. Classes
    if (searchAll || type === 'CLASS') {
      const classes = await this.prisma.class.findMany({
        where: {
          schoolId,
          OR: [
            { name: { contains: q, mode: 'insensitive' } },
            { code: { contains: q, mode: 'insensitive' } },
          ],
        },
        take: limit,
        include: { sections: true },
      });

      for (const c of classes) {
        const secList = c.sections.map((sec) => sec.name).join(', ');
        results.push({
          id: c.id,
          type: 'CLASS',
          title: c.name,
          subtitle: `Code: ${c.code} • Sections: ${secList || 'None'}`,
          routeTarget: 'ACADEMICS',
          metadata: { code: c.code },
        });
      }
    }

    // 4. Subjects
    if (searchAll || type === 'SUBJECT') {
      const subjects = await this.prisma.subject.findMany({
        where: {
          schoolId,
          OR: [
            { name: { contains: q, mode: 'insensitive' } },
            { code: { contains: q, mode: 'insensitive' } },
          ],
        },
        take: limit,
      });

      for (const sub of subjects) {
        results.push({
          id: sub.id,
          type: 'SUBJECT',
          title: sub.name,
          subtitle: `Code: ${sub.code} • Type: ${sub.type}`,
          routeTarget: 'ACADEMICS',
          metadata: { code: sub.code },
        });
      }
    }

    // 5. Circulars
    if (searchAll || type === 'CIRCULAR') {
      const circulars = await this.prisma.circular.findMany({
        where: {
          schoolId,
          OR: [
            { circularNumber: { contains: q, mode: 'insensitive' } },
            { title: { contains: q, mode: 'insensitive' } },
            { content: { contains: q, mode: 'insensitive' } },
          ],
        },
        take: limit,
      });

      for (const c of circulars) {
        results.push({
          id: c.id,
          type: 'CIRCULAR',
          title: c.title,
          subtitle: `${c.circularNumber} • Audience: ${c.targetAudience} • Priority: ${c.priority}`,
          status: c.status,
          routeTarget: 'CIRCULARS',
          metadata: { circularNumber: c.circularNumber, priority: c.priority },
        });
      }
    }

    // 6. Assignments
    if (searchAll || type === 'ASSIGNMENT') {
      const assignments = await this.prisma.assignment.findMany({
        where: {
          schoolId,
          OR: [
            { title: { contains: q, mode: 'insensitive' } },
            { description: { contains: q, mode: 'insensitive' } },
          ],
        },
        take: limit,
        include: { class: true, subject: true },
      });

      for (const a of assignments) {
        results.push({
          id: a.id,
          type: 'ASSIGNMENT',
          title: a.title,
          subtitle: `${a.subject.name} • ${a.class.name} • Max: ${a.maxMarks}`,
          status: a.status,
          routeTarget: 'ASSIGNMENTS',
          metadata: { subject: a.subject.name, class: a.class.name },
        });
      }
    }

    // 7. Invoices
    if (searchAll || type === 'INVOICE') {
      const invoices = await this.prisma.invoice.findMany({
        where: {
          schoolId,
          OR: [
            { invoiceNo: { contains: q, mode: 'insensitive' } },
            { title: { contains: q, mode: 'insensitive' } },
            { student: { firstName: { contains: q, mode: 'insensitive' } } },
            { student: { lastName: { contains: q, mode: 'insensitive' } } },
          ],
        },
        take: limit,
        include: { student: true },
      });

      for (const inv of invoices) {
        results.push({
          id: inv.id,
          type: 'INVOICE',
          title: `${inv.title} (${inv.invoiceNo})`,
          subtitle: `Student: ${inv.student.firstName} ${inv.student.lastName} • ₹${inv.amountMinor / 100}`,
          status: inv.status,
          routeTarget: 'FEES',
          metadata: { invoiceNo: inv.invoiceNo, amount: inv.amountMinor / 100 },
        });
      }
    }

    // 8. Receipts / Payments
    if (searchAll || type === 'RECEIPT') {
      const payments = await this.prisma.payment.findMany({
        where: {
          schoolId,
          OR: [
            { receiptNo: { contains: q, mode: 'insensitive' } },
            { notes: { contains: q, mode: 'insensitive' } },
            { invoice: { student: { firstName: { contains: q, mode: 'insensitive' } } } },
            { invoice: { student: { lastName: { contains: q, mode: 'insensitive' } } } },
          ],
        },
        take: limit,
        include: { invoice: { include: { student: true } } },
      });

      for (const p of payments) {
        const studentName = p.invoice?.student
          ? `${p.invoice.student.firstName} ${p.invoice.student.lastName}`
          : 'Student';
        results.push({
          id: p.id,
          type: 'RECEIPT',
          title: `Receipt ${p.receiptNo}`,
          subtitle: `Student: ${studentName} • ₹${p.amountMinor / 100} (${p.method})`,
          status: p.status,
          routeTarget: 'FEES',
          metadata: { receiptNo: p.receiptNo, method: p.method },
        });
      }
    }

    // 9. Examinations
    if (searchAll || type === 'EXAM') {
      const exams = await this.prisma.exam.findMany({
        where: {
          schoolId,
          OR: [
            { name: { contains: q, mode: 'insensitive' } },
            { term: { contains: q, mode: 'insensitive' } },
          ],
        },
        take: limit,
        include: { academicYear: true },
      });

      for (const ex of exams) {
        results.push({
          id: ex.id,
          type: 'EXAM',
          title: ex.name,
          subtitle: `Term: ${ex.term} • AY: ${ex.academicYear.name}`,
          status: ex.status,
          routeTarget: 'EXAMINATIONS',
          metadata: { term: ex.term, academicYear: ex.academicYear.name },
        });
      }
    }

    return {
      query: q,
      totalMatches: results.length,
      results,
    };
  }
}

