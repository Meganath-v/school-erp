import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  // The seed creates demo accounts with a shared, publicly known password.
  if (process.env.NODE_ENV === 'production' && process.env.ALLOW_DEMO_SEED !== 'true') {
    throw new Error('Refusing to seed demo accounts (password123) with NODE_ENV=production.');
  }
  console.log('🌱 Seeding database...');

  // 0. Clean slate for idempotent re-seeding
  await prisma.circularAcknowledgement.deleteMany();
  await prisma.circular.deleteMany();
  await prisma.feedback.deleteMany();
  await prisma.task.deleteMany();
  await prisma.reminder.deleteMany();
  await prisma.notification.deleteMany();
  await prisma.auditLog.deleteMany();
  await prisma.payment.deleteMany();
  await prisma.invoice.deleteMany();
  await prisma.mark.deleteMany();
  await prisma.submission.deleteMany();
  await prisma.attendanceRecord.deleteMany();
  await prisma.attendanceSession.deleteMany();
  await prisma.leaveRequest.deleteMany();
  await prisma.lessonPlan.deleteMany();
  await prisma.teachingDiaryEntry.deleteMany();
  await prisma.courseMaterial.deleteMany();
  await prisma.teacherAssignment.deleteMany();
  await prisma.timetableEntry.deleteMany();
  await prisma.examSubject.deleteMany();
  await prisma.exam.deleteMany();
  await prisma.assignment.deleteMany();
  await prisma.classSubject.deleteMany();
  await prisma.enrollment.deleteMany();
  await prisma.studentGuardian.deleteMany();
  await prisma.guardian.deleteMany();
  await prisma.student.deleteMany();
  await prisma.staff.deleteMany();
  await prisma.section.deleteMany();
  await prisma.class.deleteMany();
  await prisma.subject.deleteMany();
  await prisma.feePlan.deleteMany();
  await prisma.feeHead.deleteMany();
  await prisma.academicYear.deleteMany();
  await prisma.userSchoolMembership.deleteMany();
  await prisma.schoolDomain.deleteMany();
  await prisma.subscription.deleteMany();
  await prisma.school.deleteMany();

  // 1. Password Hash (password123)
  const passwordHash = await bcrypt.hash('password123', 10);

  // 2. Subscription Plans
  const starterPlan = await prisma.subscriptionPlan.upsert({
    where: { code: 'STARTER' },
    update: {},
    create: {
      code: 'STARTER',
      name: 'Starter Tier',
      priceMinor: 499900, // ₹4,999/yr
      currency: 'INR',
      billingInterval: 'YEARLY',
      studentLimit: 250,
      staffLimit: 25,
      storageLimitBytes: BigInt(5368709120), // 5 GB
      featureFlags: JSON.stringify({ attendance: true, exams: true, fees: false }),
      trialDays: 30,
      graceDays: 15,
    },
  });

  const growthPlan = await prisma.subscriptionPlan.upsert({
    where: { code: 'GROWTH' },
    update: {},
    create: {
      code: 'GROWTH',
      name: 'Growth Enterprise',
      priceMinor: 1499900, // ₹14,999/yr
      currency: 'INR',
      billingInterval: 'YEARLY',
      studentLimit: 1200,
      staffLimit: 120,
      storageLimitBytes: BigInt(26843545600), // 25 GB
      featureFlags: JSON.stringify({ attendance: true, exams: true, fees: true, timetable: true, parent_portal: true }),
      trialDays: 30,
      graceDays: 15,
    },
  });

  // 3. System Roles
  const rolesData = [
    { code: 'PLATFORM_OWNER', name: 'SaaS Platform Owner', description: 'Platform oversight, onboarding, and subscriptions' },
    { code: 'SCHOOL_ADMIN', name: 'School Administrator', description: 'Full control over school configuration and data' },
    { code: 'OFFICE', name: 'Office & Management', description: 'Admissions, student records, fee collection' },
    { code: 'PRINCIPAL', name: 'Principal / Headmaster', description: 'Academic monitoring, approvals, reports' },
    { code: 'CLASS_TEACHER', name: 'Class Teacher', description: 'Class roster, attendance, student support' },
    { code: 'SUBJECT_TEACHER', name: 'Subject Teacher', description: 'Syllabus, homework, assessments, marks' },
    { code: 'PARENT', name: 'Parent / Guardian', description: 'Access to linked children records and fee payment' },
    { code: 'STUDENT', name: 'Student', description: 'Timetable, assignments, and study materials' },
  ];

  for (const r of rolesData) {
    await prisma.role.upsert({
      where: { code: r.code },
      update: { name: r.name, description: r.description },
      create: r,
    });
  }

  // 4. Global Users
  const superAdminUser = await prisma.user.upsert({
    where: { email: 'superadmin@erp.com' },
    update: { passwordHash },
    create: {
      email: 'superadmin@erp.com',
      username: 'superadmin',
      firstName: 'Alexander',
      lastName: 'Vance',
      passwordHash,
      status: 'ACTIVE',
    },
  });

  const oakAdminUser = await prisma.user.upsert({
    where: { email: 'admin@oakridge.edu' },
    update: { passwordHash },
    create: {
      email: 'admin@oakridge.edu',
      username: 'oakadmin',
      firstName: 'Marcus',
      lastName: 'Sterling',
      passwordHash,
      status: 'ACTIVE',
    },
  });

  const principalUser = await prisma.user.upsert({
    where: { email: 'principal@oakridge.edu' },
    update: { passwordHash },
    create: {
      email: 'principal@oakridge.edu',
      username: 'oakprincipal',
      firstName: 'Dr. Robert',
      lastName: 'Hayes',
      passwordHash,
      status: 'ACTIVE',
    },
  });

  const officeUser = await prisma.user.upsert({
    where: { email: 'office@oakridge.edu' },
    update: { passwordHash },
    create: {
      email: 'office@oakridge.edu',
      username: 'oakoffice',
      firstName: 'Eleanor',
      lastName: 'Pence',
      passwordHash,
      status: 'ACTIVE',
    },
  });

  const classTeacherUser = await prisma.user.upsert({
    where: { email: 'teacher.smith@oakridge.edu' },
    update: { passwordHash },
    create: {
      email: 'teacher.smith@oakridge.edu',
      username: 'teachersmith',
      firstName: 'Sarah',
      lastName: 'Smith',
      passwordHash,
      status: 'ACTIVE',
    },
  });

  const subjectTeacherUser = await prisma.user.upsert({
    where: { email: 'teacher.jones@oakridge.edu' },
    update: { passwordHash },
    create: {
      email: 'teacher.jones@oakridge.edu',
      username: 'teacherjones',
      firstName: 'David',
      lastName: 'Jones',
      passwordHash,
      status: 'ACTIVE',
    },
  });

  const parentUser = await prisma.user.upsert({
    where: { email: 'parent.doe@gmail.com' },
    update: { passwordHash },
    create: {
      email: 'parent.doe@gmail.com',
      username: 'michaeldoe',
      firstName: 'Michael',
      lastName: 'Doe',
      phone: '+91 9876543219',
      passwordHash,
      status: 'ACTIVE',
    },
  });

  const studentUser = await prisma.user.upsert({
    where: { email: 'student.john@oakridge.edu' },
    update: { passwordHash },
    create: {
      email: 'student.john@oakridge.edu',
      username: 'studentjohn',
      firstName: 'John',
      lastName: 'Doe',
      phone: '+91 9876543220',
      passwordHash,
      status: 'ACTIVE',
    },
  });

  // Second school admin
  const stxAdminUser = await prisma.user.upsert({
    where: { email: 'admin@stxaviers.edu' },
    update: { passwordHash },
    create: {
      email: 'admin@stxaviers.edu',
      username: 'stxadmin',
      firstName: 'Father Francis',
      lastName: 'DeSouza',
      passwordHash,
      status: 'ACTIVE',
    },
  });

  // 5. Schools (Tenants)
  const oakridgeSchool = await prisma.school.upsert({
    where: { code: 'OAK01' },
    update: {},
    create: {
      code: 'OAK01',
      name: 'Oakridge International School',
      slug: 'oakridge',
      status: 'ACTIVE',
      timezone: 'Asia/Kolkata',
      locale: 'en_IN',
      currency: 'INR',
      address: '100 Greenfield Boulevard, Outer Ring Road, Bengaluru, KA',
      contactEmail: 'contact@oakridge.edu',
      contactPhone: '+91 80 4912 3000',
    },
  });

  const stxaviersSchool = await prisma.school.upsert({
    where: { code: 'STX02' },
    update: {},
    create: {
      code: 'STX02',
      name: "St. Xavier's High School",
      slug: 'stxaviers',
      status: 'ACTIVE',
      timezone: 'Asia/Kolkata',
      locale: 'en_IN',
      currency: 'INR',
      address: '45 Heritage Way, Fort, Mumbai, MH',
      contactEmail: 'admissions@stxaviers.edu',
      contactPhone: '+91 22 2262 0455',
    },
  });

  // Subscriptions
  await prisma.subscription.create({
    data: {
      schoolId: oakridgeSchool.id,
      planId: growthPlan.id,
      status: 'ACTIVE',
      startsAt: new Date('2026-01-01'),
      endsAt: new Date('2027-01-01'),
      providerRef: 'SUB_GROWTH_OAK_001',
    },
  });

  await prisma.subscription.create({
    data: {
      schoolId: stxaviersSchool.id,
      planId: starterPlan.id,
      status: 'ACTIVE',
      startsAt: new Date('2026-01-01'),
      endsAt: new Date('2027-01-01'),
      providerRef: 'SUB_STARTER_STX_002',
    },
  });

  // 6. User-School Memberships & Roles
  // Superadmin gets membership in Oakridge as PLATFORM_OWNER
  await prisma.userSchoolMembership.upsert({
    where: { userId_schoolId: { userId: superAdminUser.id, schoolId: oakridgeSchool.id } },
    update: {},
    create: {
      userId: superAdminUser.id,
      schoolId: oakridgeSchool.id,
      defaultRole: 'PLATFORM_OWNER',
      status: 'ACTIVE',
    },
  });

  // Oakridge Admin
  await prisma.userSchoolMembership.upsert({
    where: { userId_schoolId: { userId: oakAdminUser.id, schoolId: oakridgeSchool.id } },
    update: {},
    create: {
      userId: oakAdminUser.id,
      schoolId: oakridgeSchool.id,
      defaultRole: 'SCHOOL_ADMIN',
      status: 'ACTIVE',
    },
  });

  // Oakridge Principal
  await prisma.userSchoolMembership.upsert({
    where: { userId_schoolId: { userId: principalUser.id, schoolId: oakridgeSchool.id } },
    update: {},
    create: {
      userId: principalUser.id,
      schoolId: oakridgeSchool.id,
      defaultRole: 'PRINCIPAL',
      status: 'ACTIVE',
    },
  });

  // Oakridge Office
  await prisma.userSchoolMembership.upsert({
    where: { userId_schoolId: { userId: officeUser.id, schoolId: oakridgeSchool.id } },
    update: {},
    create: {
      userId: officeUser.id,
      schoolId: oakridgeSchool.id,
      defaultRole: 'OFFICE',
      status: 'ACTIVE',
    },
  });

  // Oakridge Class Teacher
  await prisma.userSchoolMembership.upsert({
    where: { userId_schoolId: { userId: classTeacherUser.id, schoolId: oakridgeSchool.id } },
    update: {},
    create: {
      userId: classTeacherUser.id,
      schoolId: oakridgeSchool.id,
      defaultRole: 'CLASS_TEACHER',
      status: 'ACTIVE',
    },
  });

  // Oakridge Subject Teacher
  await prisma.userSchoolMembership.upsert({
    where: { userId_schoolId: { userId: subjectTeacherUser.id, schoolId: oakridgeSchool.id } },
    update: {},
    create: {
      userId: subjectTeacherUser.id,
      schoolId: oakridgeSchool.id,
      defaultRole: 'SUBJECT_TEACHER',
      status: 'ACTIVE',
    },
  });

  // Oakridge Parent (Also demo multi-school membership: parent belongs to Oakridge AND St. Xavier's!)
  await prisma.userSchoolMembership.upsert({
    where: { userId_schoolId: { userId: parentUser.id, schoolId: oakridgeSchool.id } },
    update: {},
    create: {
      userId: parentUser.id,
      schoolId: oakridgeSchool.id,
      defaultRole: 'PARENT',
      status: 'ACTIVE',
    },
  });

  await prisma.userSchoolMembership.upsert({
    where: { userId_schoolId: { userId: parentUser.id, schoolId: stxaviersSchool.id } },
    update: {},
    create: {
      userId: parentUser.id,
      schoolId: stxaviersSchool.id,
      defaultRole: 'PARENT',
      status: 'ACTIVE',
    },
  });

  // Oakridge Student
  await prisma.userSchoolMembership.upsert({
    where: { userId_schoolId: { userId: studentUser.id, schoolId: oakridgeSchool.id } },
    update: {},
    create: {
      userId: studentUser.id,
      schoolId: oakridgeSchool.id,
      defaultRole: 'STUDENT',
      status: 'ACTIVE',
    },
  });

  // St. Xavier's Admin
  await prisma.userSchoolMembership.upsert({
    where: { userId_schoolId: { userId: stxAdminUser.id, schoolId: stxaviersSchool.id } },
    update: {},
    create: {
      userId: stxAdminUser.id,
      schoolId: stxaviersSchool.id,
      defaultRole: 'SCHOOL_ADMIN',
      status: 'ACTIVE',
    },
  });

  // 7. Academic Year for Oakridge
  const academicYear2026 = await prisma.academicYear.create({
    data: {
      schoolId: oakridgeSchool.id,
      name: '2026-2027',
      startDate: new Date('2026-06-01'),
      endDate: new Date('2027-04-30'),
      isCurrent: true,
      status: 'ACTIVE',
    },
  });

  // 8. Classes & Sections for Oakridge
  const grade10 = await prisma.class.create({
    data: {
      schoolId: oakridgeSchool.id,
      name: 'Grade 10',
      code: 'G10',
      orderIndex: 10,
    },
  });

  const grade9 = await prisma.class.create({
    data: {
      schoolId: oakridgeSchool.id,
      name: 'Grade 9',
      code: 'G9',
      orderIndex: 9,
    },
  });

  const sec10A = await prisma.section.create({
    data: {
      schoolId: oakridgeSchool.id,
      classId: grade10.id,
      name: 'Section A',
      room: 'Room 101',
      capacity: 35,
    },
  });

  const sec10B = await prisma.section.create({
    data: {
      schoolId: oakridgeSchool.id,
      classId: grade10.id,
      name: 'Section B',
      room: 'Room 102',
      capacity: 35,
    },
  });

  const sec9A = await prisma.section.create({
    data: {
      schoolId: oakridgeSchool.id,
      classId: grade9.id,
      name: 'Section A',
      room: 'Room 201',
      capacity: 40,
    },
  });

  // 9. Subjects for Oakridge
  const math = await prisma.subject.create({
    data: { schoolId: oakridgeSchool.id, name: 'Mathematics', code: 'MATH10', type: 'CORE' },
  });
  const science = await prisma.subject.create({
    data: { schoolId: oakridgeSchool.id, name: 'Science', code: 'SCI10', type: 'CORE' },
  });
  const english = await prisma.subject.create({
    data: { schoolId: oakridgeSchool.id, name: 'English Literature', code: 'ENG10', type: 'CORE' },
  });
  const compSci = await prisma.subject.create({
    data: { schoolId: oakridgeSchool.id, name: 'Computer Science', code: 'CS10', type: 'CORE' },
  });

  // Link subjects to Class
  await prisma.classSubject.create({ data: { schoolId: oakridgeSchool.id, classId: grade10.id, subjectId: math.id } });
  await prisma.classSubject.create({ data: { schoolId: oakridgeSchool.id, classId: grade10.id, subjectId: science.id } });
  await prisma.classSubject.create({ data: { schoolId: oakridgeSchool.id, classId: grade10.id, subjectId: english.id } });
  await prisma.classSubject.create({ data: { schoolId: oakridgeSchool.id, classId: grade10.id, subjectId: compSci.id } });

  // 10. Staff Records
  const staffSmith = await prisma.staff.create({
    data: {
      schoolId: oakridgeSchool.id,
      userId: classTeacherUser.id,
      employeeNo: 'EMP-104',
      firstName: 'Sarah',
      lastName: 'Smith',
      designation: 'Senior Mathematics Teacher',
      department: 'Mathematics',
      phone: '+91 98765 00001',
      email: 'teacher.smith@oakridge.edu',
      joiningDate: new Date('2022-05-15'),
      status: 'ACTIVE',
    },
  });

  const staffJones = await prisma.staff.create({
    data: {
      schoolId: oakridgeSchool.id,
      userId: subjectTeacherUser.id,
      employeeNo: 'EMP-105',
      firstName: 'David',
      lastName: 'Jones',
      designation: 'Science Faculty Lead',
      department: 'Science',
      phone: '+91 98765 00002',
      email: 'teacher.jones@oakridge.edu',
      joiningDate: new Date('2023-06-01'),
      status: 'ACTIVE',
    },
  });

  // Teacher Assignments
  await prisma.teacherAssignment.create({
    data: {
      schoolId: oakridgeSchool.id,
      staffId: staffSmith.id,
      classId: grade10.id,
      sectionId: sec10A.id,
      subjectId: math.id,
      isClassTeacher: true,
    },
  });

  await prisma.teacherAssignment.create({
    data: {
      schoolId: oakridgeSchool.id,
      staffId: staffJones.id,
      classId: grade10.id,
      sectionId: sec10A.id,
      subjectId: science.id,
      isClassTeacher: false,
    },
  });

  // 11. Students & Guardian
  const guardianMichael = await prisma.guardian.create({
    data: {
      schoolId: oakridgeSchool.id,
      userId: parentUser.id,
      name: 'Michael Doe',
      relation: 'FATHER',
      phone: '+91 98765 43219',
      email: 'parent.doe@gmail.com',
      occupation: 'Software Architect',
    },
  });

  // Student 1: John Doe (Grade 10-A)
  const studentJohn = await prisma.student.create({
    data: {
      schoolId: oakridgeSchool.id,
      userId: studentUser.id,
      admissionNo: 'ADM-2026-001',
      firstName: 'John',
      lastName: 'Doe',
      dob: new Date('2011-04-12'),
      gender: 'MALE',
      bloodGroup: 'O+',
      address: '742 Evergreen Terrace, Bengaluru',
      emergencyContact: '+91 98765 43219',
      status: 'ACTIVE',
    },
  });

  await prisma.studentGuardian.create({
    data: {
      studentId: studentJohn.id,
      guardianId: guardianMichael.id,
      relationship: 'FATHER',
      isPrimary: true,
      canAccessPortal: true,
    },
  });

  await prisma.enrollment.create({
    data: {
      schoolId: oakridgeSchool.id,
      studentId: studentJohn.id,
      academicYearId: academicYear2026.id,
      classId: grade10.id,
      sectionId: sec10A.id,
      rollNo: 1,
      status: 'ACTIVE',
    },
  });

  // Student 2: Emily Doe (Grade 9-A)
  const studentEmily = await prisma.student.create({
    data: {
      schoolId: oakridgeSchool.id,
      admissionNo: 'ADM-2026-002',
      firstName: 'Emily',
      lastName: 'Doe',
      dob: new Date('2012-08-20'),
      gender: 'FEMALE',
      bloodGroup: 'A+',
      address: '742 Evergreen Terrace, Bengaluru',
      emergencyContact: '+91 98765 43219',
      status: 'ACTIVE',
    },
  });

  await prisma.studentGuardian.create({
    data: {
      studentId: studentEmily.id,
      guardianId: guardianMichael.id,
      relationship: 'FATHER',
      isPrimary: true,
      canAccessPortal: true,
    },
  });

  await prisma.enrollment.create({
    data: {
      schoolId: oakridgeSchool.id,
      studentId: studentEmily.id,
      academicYearId: academicYear2026.id,
      classId: grade9.id,
      sectionId: sec9A.id,
      rollNo: 5,
      status: 'ACTIVE',
    },
  });

  // More Students in Grade 10-A
  const studentAlex = await prisma.student.create({
    data: {
      schoolId: oakridgeSchool.id,
      admissionNo: 'ADM-2026-003',
      firstName: 'Alex',
      lastName: 'Johnson',
      dob: new Date('2011-02-14'),
      gender: 'MALE',
      bloodGroup: 'B+',
      status: 'ACTIVE',
    },
  });
  await prisma.enrollment.create({
    data: {
      schoolId: oakridgeSchool.id,
      studentId: studentAlex.id,
      academicYearId: academicYear2026.id,
      classId: grade10.id,
      sectionId: sec10A.id,
      rollNo: 2,
    },
  });

  const studentPriya = await prisma.student.create({
    data: {
      schoolId: oakridgeSchool.id,
      admissionNo: 'ADM-2026-004',
      firstName: 'Priya',
      lastName: 'Sharma',
      dob: new Date('2011-09-05'),
      gender: 'FEMALE',
      bloodGroup: 'AB+',
      status: 'ACTIVE',
    },
  });
  await prisma.enrollment.create({
    data: {
      schoolId: oakridgeSchool.id,
      studentId: studentPriya.id,
      academicYearId: academicYear2026.id,
      classId: grade10.id,
      sectionId: sec10A.id,
      rollNo: 3,
    },
  });

  const studentLucas = await prisma.student.create({
    data: {
      schoolId: oakridgeSchool.id,
      admissionNo: 'ADM-2026-005',
      firstName: 'Lucas',
      lastName: 'Brown',
      dob: new Date('2011-11-28'),
      gender: 'MALE',
      bloodGroup: 'O-',
      status: 'ACTIVE',
    },
  });
  await prisma.enrollment.create({
    data: {
      schoolId: oakridgeSchool.id,
      studentId: studentLucas.id,
      academicYearId: academicYear2026.id,
      classId: grade10.id,
      sectionId: sec10A.id,
      rollNo: 4,
    },
  });

  // 12. Attendance Session & Records for Grade 10-A
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const attendanceSession = await prisma.attendanceSession.create({
    data: {
      schoolId: oakridgeSchool.id,
      sectionId: sec10A.id,
      date: today,
      sessionType: 'DAILY',
      status: 'SUBMITTED',
      createdBy: 'Sarah Smith',
    },
  });

  await prisma.attendanceRecord.createMany({
    data: [
      { sessionId: attendanceSession.id, studentId: studentJohn.id, status: 'PRESENT' },
      { sessionId: attendanceSession.id, studentId: studentAlex.id, status: 'PRESENT' },
      { sessionId: attendanceSession.id, studentId: studentPriya.id, status: 'ABSENT', remarks: 'Medical appointment' },
      { sessionId: attendanceSession.id, studentId: studentLucas.id, status: 'LATE', remarks: 'Arrived 15m late' },
    ],
  });

  // 13. Timetable Entries
  const timetableSlots = [
    { day: 1, period: 1, start: '08:30', end: '09:15', sub: math.id, staff: staffSmith.id, room: '101' },
    { day: 1, period: 2, start: '09:20', end: '10:05', sub: science.id, staff: staffJones.id, room: '101' },
    { day: 1, period: 3, start: '10:25', end: '11:10', sub: english.id, staff: staffSmith.id, room: '101' },
    { day: 1, period: 4, start: '11:15', end: '12:00', sub: compSci.id, staff: staffJones.id, room: 'Lab 2' },
    { day: 2, period: 1, start: '08:30', end: '09:15', sub: science.id, staff: staffJones.id, room: '101' },
    { day: 2, period: 2, start: '09:20', end: '10:05', sub: math.id, staff: staffSmith.id, room: '101' },
    { day: 3, period: 1, start: '08:30', end: '09:15', sub: compSci.id, staff: staffJones.id, room: 'Lab 2' },
  ];

  for (const slot of timetableSlots) {
    await prisma.timetableEntry.create({
      data: {
        schoolId: oakridgeSchool.id,
        academicYearId: academicYear2026.id,
        classId: grade10.id,
        sectionId: sec10A.id,
        subjectId: slot.sub,
        staffId: slot.staff,
        dayOfWeek: slot.day,
        periodNumber: slot.period,
        startTime: slot.start,
        endTime: slot.end,
        room: slot.room,
      },
    });
  }

  // 14. Assignments / Homework
  const hwMath = await prisma.assignment.create({
    data: {
      schoolId: oakridgeSchool.id,
      classId: grade10.id,
      sectionId: sec10A.id,
      subjectId: math.id,
      teacherId: staffSmith.id,
      title: 'Quadratic Equations Exercise 4.2',
      description: 'Solve questions 1 through 15 from Chapter 4 on quadratic roots and word problems.',
      dueDate: new Date(Date.now() + 3 * 24 * 3600 * 1000),
      maxMarks: 25,
      status: 'ACTIVE',
    },
  });

  const hwScience = await prisma.assignment.create({
    data: {
      schoolId: oakridgeSchool.id,
      classId: grade10.id,
      sectionId: sec10A.id,
      subjectId: science.id,
      teacherId: staffJones.id,
      title: 'Chemical Reactions & Catalyst Lab Writeup',
      description: 'Submit your typed experimental findings and balanced equations from Tuesday lab session.',
      dueDate: new Date(Date.now() + 5 * 24 * 3600 * 1000),
      maxMarks: 50,
      status: 'ACTIVE',
    },
  });

  // Submission for John Doe
  await prisma.submission.create({
    data: {
      assignmentId: hwMath.id,
      studentId: studentJohn.id,
      status: 'REVIEWED',
      marksObtained: 24,
      feedback: 'Excellent breakdown of steps. Watch out for negative signs in question 8.',
      notes: 'Completed questions 1-15 on notebook sheets.',
    },
  });

  // 15. Examination & Marks
  const midTermExam = await prisma.exam.create({
    data: {
      schoolId: oakridgeSchool.id,
      academicYearId: academicYear2026.id,
      name: 'Mid-Term Summative Assessment 2026',
      term: 'TERM_1',
      startDate: new Date('2026-09-15'),
      endDate: new Date('2026-09-25'),
      status: 'PUBLISHED',
    },
  });

  const examMath = await prisma.examSubject.create({
    data: {
      examId: midTermExam.id,
      classId: grade10.id,
      subjectId: math.id,
      examDate: new Date('2026-09-16'),
      maxMarks: 100,
      passMarks: 40,
    },
  });

  const examScience = await prisma.examSubject.create({
    data: {
      examId: midTermExam.id,
      classId: grade10.id,
      subjectId: science.id,
      examDate: new Date('2026-09-18'),
      maxMarks: 100,
      passMarks: 40,
    },
  });

  await prisma.mark.createMany({
    data: [
      { examSubjectId: examMath.id, studentId: studentJohn.id, marksObtained: 94, remarks: 'Grade A+ (Distinction)' },
      { examSubjectId: examScience.id, studentId: studentJohn.id, marksObtained: 89, remarks: 'Grade A' },
      { examSubjectId: examMath.id, studentId: studentAlex.id, marksObtained: 76, remarks: 'Grade B+' },
      { examSubjectId: examScience.id, studentId: studentAlex.id, marksObtained: 82, remarks: 'Grade A-' },
      { examSubjectId: examMath.id, studentId: studentPriya.id, marksObtained: 98, remarks: 'Highest in Class' },
      { examSubjectId: examScience.id, studentId: studentPriya.id, marksObtained: 95, remarks: 'Distinction' },
    ],
  });

  // 16. Fee Heads, Plans & Invoices
  await prisma.feeHead.createMany({
    data: [
      { schoolId: oakridgeSchool.id, name: 'Tuition Fee', code: 'TUIT' },
      { schoolId: oakridgeSchool.id, name: 'Science & Computer Lab Fee', code: 'LAB' },
      { schoolId: oakridgeSchool.id, name: 'Library & Activity Fee', code: 'LIB' },
    ],
  });

  const feePlan10 = await prisma.feePlan.create({
    data: {
      schoolId: oakridgeSchool.id,
      academicYearId: academicYear2026.id,
      classId: grade10.id,
      name: 'Grade 10 Annual Comprehensive Fee Plan',
      totalAmountMinor: 6500000, // ₹65,000
      currency: 'INR',
    },
  });

  const invoiceJohn = await prisma.invoice.create({
    data: {
      schoolId: oakridgeSchool.id,
      studentId: studentJohn.id,
      invoiceNo: 'INV-2026-001',
      title: 'Term 1 Tuition & Laboratory Fee',
      category: 'SCHOOL',
      amountMinor: 3250000, // ₹32,500
      paidAmountMinor: 3250000,
      dueAmountMinor: 0,
      dueDate: new Date('2026-07-15'),
      status: 'PAID',
    },
  });

  await prisma.payment.create({
    data: {
      schoolId: oakridgeSchool.id,
      invoiceId: invoiceJohn.id,
      amountMinor: 3250000,
      method: 'ONLINE',
      status: 'SUCCESS',
      transactionRef: 'RZP_PAY_928172901',
      receiptNo: 'REC-2026-00084',
      notes: 'Paid via Razorpay Netbanking',
    },
  });

  // Hostel Fee Invoice (Section 7)
  const invoiceJohnHostel = await prisma.invoice.create({
    data: {
      schoolId: oakridgeSchool.id,
      studentId: studentJohn.id,
      invoiceNo: 'INV-2026-003',
      title: 'Quarter 1 Boarding & Mess Charges',
      category: 'HOSTEL',
      amountMinor: 2400000, // ₹24,000
      paidAmountMinor: 1200000,
      dueAmountMinor: 1200000,
      dueDate: new Date(Date.now() + 15 * 24 * 3600 * 1000),
      status: 'PARTIAL',
    },
  });

  await prisma.payment.create({
    data: {
      schoolId: oakridgeSchool.id,
      invoiceId: invoiceJohnHostel.id,
      amountMinor: 1200000,
      method: 'ONLINE',
      status: 'SUCCESS',
      transactionRef: 'RZP_PAY_928173499',
      receiptNo: 'REC-2026-00095',
      notes: 'Hostel Advance Installment Paid',
    },
  });

  // Transport Fee Invoice (Section 7)
  await prisma.invoice.create({
    data: {
      schoolId: oakridgeSchool.id,
      studentId: studentJohn.id,
      invoiceNo: 'INV-2026-004',
      title: 'Bus Route #12 Campus Transport Fee',
      category: 'TRANSPORT',
      amountMinor: 850000, // ₹8,500
      paidAmountMinor: 0,
      dueAmountMinor: 850000,
      dueDate: new Date(Date.now() + 5 * 24 * 3600 * 1000),
      status: 'PENDING',
    },
  });

  const invoiceEmily = await prisma.invoice.create({
    data: {
      schoolId: oakridgeSchool.id,
      studentId: studentEmily.id,
      invoiceNo: 'INV-2026-002',
      title: 'Term 1 Tuition Fee',
      category: 'SCHOOL',
      amountMinor: 2800000, // ₹28,000
      paidAmountMinor: 0,
      dueAmountMinor: 2800000,
      dueDate: new Date(Date.now() + 10 * 24 * 3600 * 1000),
      status: 'PENDING',
    },
  });

  // 17. Announcements
  await prisma.announcement.createMany({
    data: [
      {
        schoolId: oakridgeSchool.id,
        title: 'Annual Sports Day 2026 Registrations Open',
        content: 'Inter-house athletic trials will begin next Wednesday. All students from Grades 6 to 12 can register with the Physical Education department.',
        targetRole: 'ALL',
        priority: 'NORMAL',
        authorName: 'Dr. Robert Hayes (Principal)',
      },
      {
        schoolId: oakridgeSchool.id,
        title: 'Term 1 Parent-Teacher Meeting Schedule',
        content: 'Individual academic review slots will be held on Saturday between 09:00 AM and 01:00 PM in the Main Auditorium.',
        targetRole: 'PARENT',
        priority: 'URGENT',
        authorName: 'Office Administration',
      },
    ],
  });

  // 18. Leave Requests
  await prisma.leaveRequest.create({
    data: {
      schoolId: oakridgeSchool.id,
      studentId: studentJohn.id,
      applicantName: 'Michael Doe (Father)',
      startDate: new Date(Date.now() + 2 * 24 * 3600 * 1000),
      endDate: new Date(Date.now() + 3 * 24 * 3600 * 1000),
      reason: 'Attending family wedding out of town.',
      status: 'PENDING',
    },
  });

  // 19. Audit Logs
  await prisma.auditLog.createMany({
    data: [
      {
        schoolId: oakridgeSchool.id,
        actorId: superAdminUser.id,
        actorName: 'Alexander Vance',
        action: 'TENANT_PROVISIONED',
        entity: 'School',
        entityId: oakridgeSchool.id,
        details: JSON.stringify({ code: 'OAK01', name: 'Oakridge International School' }),
      },
      {
        schoolId: oakridgeSchool.id,
        actorId: classTeacherUser.id,
        actorName: 'Sarah Smith',
        action: 'ATTENDANCE_MARKED',
        entity: 'AttendanceSession',
        entityId: attendanceSession.id,
        details: JSON.stringify({ class: 'Grade 10', section: 'Section A', present: 2, absent: 1, late: 1 }),
      },
      {
        schoolId: oakridgeSchool.id,
        actorId: parentUser.id,
        actorName: 'Michael Doe',
        action: 'INVOICE_PAID',
        entity: 'Invoice',
        entityId: invoiceJohn.id,
        details: JSON.stringify({ invoiceNo: 'INV-2026-001', amount: 32500 }),
      },
    ],
  });

  // 19.1 Notifications (v2.1 Workflow)
  await prisma.notification.createMany({
    data: [
      {
        schoolId: oakridgeSchool.id,
        userId: parentUser.id,
        title: 'Fee Invoices Published',
        body: 'New School, Hostel, and Transport fee invoices are now available for review and online payment.',
        channel: 'IN_APP',
        status: 'UNREAD',
        eventKey: 'FEE_PUBLISHED_2026',
      },
      {
        schoolId: oakridgeSchool.id,
        userId: parentUser.id,
        title: 'Term 1 Mid-Term Report Card Released',
        body: 'Academic performance report cards for Grade 10 have been officially published.',
        channel: 'IN_APP',
        status: 'READ',
        eventKey: 'RESULTS_PUBLISHED_TERM1',
      },
      {
        schoolId: oakridgeSchool.id,
        userId: classTeacherUser.id,
        title: 'Pending Student Leave Application',
        body: 'Michael Doe submitted a leave application for John Doe.',
        channel: 'IN_APP',
        status: 'UNREAD',
        eventKey: 'LEAVE_REQUEST_PENDING',
      },
    ],
  });

  // 20. Linways OBE: Course Delivery Plans (Lesson Plans)
  await prisma.lessonPlan.createMany({
    data: [
      {
        schoolId: oakridgeSchool.id,
        classId: grade10.id,
        subjectId: math.id,
        teacherId: staffSmith.id,
        unitNumber: 1,
        unitTitle: 'Real Numbers & Polynomials',
        topic: 'Fundamental Theorem of Arithmetic, zeros of polynomials, and division algorithm.',
        learningObjectives: 'Apply Euclid division lemma; analyze relationship between zeroes and coefficients of polynomials.',
        plannedHours: 8,
        conductedHours: 8,
        status: 'COMPLETED',
      },
      {
        schoolId: oakridgeSchool.id,
        classId: grade10.id,
        subjectId: math.id,
        teacherId: staffSmith.id,
        unitNumber: 2,
        unitTitle: 'Quadratic Equations & Roots',
        topic: 'Standard form ax² + bx + c = 0, factorization method, completing square, quadratic formula.',
        learningObjectives: 'Determine discriminant and classify roots of quadratic equations with real-world modelling.',
        plannedHours: 12,
        conductedHours: 10,
        status: 'IN_PROGRESS',
      },
      {
        schoolId: oakridgeSchool.id,
        classId: grade10.id,
        subjectId: math.id,
        teacherId: staffSmith.id,
        unitNumber: 3,
        unitTitle: 'Arithmetic Progressions',
        topic: 'nth term of an AP, sum of first n terms of an AP and application in solving daily life problems.',
        learningObjectives: 'Formulate sequence equations and compute summations efficiently.',
        plannedHours: 8,
        conductedHours: 0,
        status: 'PENDING',
      },
      {
        schoolId: oakridgeSchool.id,
        classId: grade10.id,
        subjectId: science.id,
        teacherId: staffJones.id,
        unitNumber: 1,
        unitTitle: 'Chemical Reactions & Catalysts',
        topic: 'Types of chemical reactions: combination, decomposition, displacement, double displacement, precipitation.',
        learningObjectives: 'Balance redox reactions and observe color changes in transition state catalysts.',
        plannedHours: 8,
        conductedHours: 8,
        status: 'COMPLETED',
      },
      {
        schoolId: oakridgeSchool.id,
        classId: grade10.id,
        subjectId: science.id,
        teacherId: staffJones.id,
        unitNumber: 2,
        unitTitle: 'Acids, Bases and Salts',
        topic: 'Definitions in terms of furnishing of H+ and OH- ions, general properties, examples and uses.',
        learningObjectives: 'Measure pH scale values and write salt neutralization formulations.',
        plannedHours: 10,
        conductedHours: 6,
        status: 'IN_PROGRESS',
      },
    ],
  });

  // 21. Linways Faculty Teaching Diary (Course Log)
  await prisma.teachingDiaryEntry.createMany({
    data: [
      {
        schoolId: oakridgeSchool.id,
        classId: grade10.id,
        sectionId: sec10A.id,
        subjectId: math.id,
        teacherId: staffSmith.id,
        date: new Date(Date.now() - 2 * 24 * 3600 * 1000),
        periodNumber: 1,
        topicTaught: 'Quadratic Formula derivation using completing the square method. Solved 4 board problems.',
        methodology: 'LECTURE',
        remarks: 'Class engaged enthusiastically. Assigned question set 4.2 for home study.',
      },
      {
        schoolId: oakridgeSchool.id,
        classId: grade10.id,
        sectionId: sec10A.id,
        subjectId: math.id,
        teacherId: staffSmith.id,
        date: new Date(Date.now() - 1 * 24 * 3600 * 1000),
        periodNumber: 2,
        topicTaught: 'Discriminant analysis (b² - 4ac > 0, = 0, < 0) and nature of real vs complex roots.',
        methodology: 'GROUP_DISCUSSION',
        remarks: 'Small group problem solving in groups of 4. High conceptual clarity achieved.',
      },
      {
        schoolId: oakridgeSchool.id,
        classId: grade10.id,
        sectionId: sec10A.id,
        subjectId: science.id,
        teacherId: staffJones.id,
        date: new Date(Date.now() - 1 * 24 * 3600 * 1000),
        periodNumber: 1,
        topicTaught: 'Laboratory titration of hydrochloric acid with sodium hydroxide indicator.',
        methodology: 'LAB',
        remarks: 'Conducted in Chemistry Lab 2. All safety protocols followed; report writeups due Friday.',
      },
    ],
  });

  // 22. Linways Digital Course Repository (Learning Materials)
  await prisma.courseMaterial.createMany({
    data: [
      {
        schoolId: oakridgeSchool.id,
        subjectId: math.id,
        title: 'Unit 2: Quadratic Equations Complete Master Notes & Solutions',
        unitNumber: 2,
        fileType: 'PDF',
        fileUrl: 'https://docs.erp.com/oakridge/math10/unit2_quadratic_guide.pdf',
        uploadedBy: 'Sarah Smith (Faculty)',
      },
      {
        schoolId: oakridgeSchool.id,
        subjectId: math.id,
        title: 'Formula Quick-Reference Sheet - Class 10 Board Prep',
        unitNumber: 1,
        fileType: 'PDF',
        fileUrl: 'https://docs.erp.com/oakridge/math10/board_formula_sheet.pdf',
        uploadedBy: 'Sarah Smith (Faculty)',
      },
      {
        schoolId: oakridgeSchool.id,
        subjectId: science.id,
        title: 'Chemical Reactions & Balancing Equations Lecture Slides',
        unitNumber: 1,
        fileType: 'SLIDES',
        fileUrl: 'https://docs.erp.com/oakridge/sci10/reactions_deck.pptx',
        uploadedBy: 'David Jones (Faculty)',
      },
      {
        schoolId: oakridgeSchool.id,
        subjectId: compSci.id,
        title: 'Python Programming Algorithms & Flowcharts Handbook',
        unitNumber: 1,
        fileType: 'PDF',
        fileUrl: 'https://docs.erp.com/oakridge/cs10/python_algorithms.pdf',
        uploadedBy: 'David Jones (Faculty)',
      },
    ],
  });

  // 17. Seed Circulars (Office Employee & Class Teacher sent)
  console.log('📢 Seeding circulars...');
  const officeCircular = await prisma.circular.create({
    data: {
      schoolId: oakridgeSchool.id,
      circularNumber: 'CIR/2026/001',
      title: 'Annual Day Celebrations & Rehearsal Schedule',
      content: 'Dear Parents and Staff, The Annual Day Gala will be celebrated on December 15th. Rehearsals will commence next Monday from 2:00 PM to 4:00 PM. Transport arrangements have been made for participating students. Kindly acknowledge receipt of this circular.',
      senderType: 'OFFICE_EMPLOYEE',
      senderId: officeUser.id,
      senderName: 'Eleanor Pence (Office Administration)',
      targetAudience: 'ALL',
      priority: 'IMPORTANT',
      requiresAck: true,
      ackDeadline: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      status: 'PUBLISHED',
      publishedAt: new Date(),
    },
  });

  const classTeacherCircular = await prisma.circular.create({
    data: {
      schoolId: oakridgeSchool.id,
      circularNumber: 'CIR/2026/002',
      title: 'Class 10-A Science Museum Field Trip & Parent Consent',
      content: 'Dear Parents of Class 10-A, Our class will be visiting the Regional Science City on Friday, November 28th. Students must wear school uniform with ID cards. Please review the attached itinerary and confirm student participation consent.',
      senderType: 'CLASS_TEACHER',
      senderId: classTeacherUser.id,
      senderName: 'Sarah Smith (Class Teacher, 10-A)',
      targetAudience: 'CLASS_PARENTS',
      classId: grade10.id,
      sectionId: sec10A.id,
      priority: 'NORMAL',
      requiresAck: true,
      ackDeadline: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000),
      status: 'PUBLISHED',
      publishedAt: new Date(),
    },
  });

  // Parent acknowledgement for office circular
  await prisma.circularAcknowledgement.create({
    data: {
      circularId: officeCircular.id,
      userId: parentUser.id,
      userName: 'Michael Doe (Parent)',
      userRole: 'PARENT',
      acknowledgedAt: new Date(),
      remarks: 'Noted with thanks. Alexander Doe will participate in choir.',
    },
  });

  // 18. Seed Feedbacks
  console.log('💬 Seeding feedbacks...');
  await prisma.feedback.createMany({
    data: [
      {
        schoolId: oakridgeSchool.id,
        submitterId: parentUser.id,
        targetType: 'TEACHER',
        targetId: classTeacherUser.id,
        targetName: 'Sarah Smith (Class Teacher)',
        category: 'ACADEMIC',
        title: 'Appreciation for Extra Doubt Clearing Sessions',
        content: 'I would like to express our appreciation for Mrs. Smith taking extra time after school hours to help students with algebra doubt resolution.',
        rating: 5,
        isAnonymous: false,
        status: 'RESOLVED',
        response: 'Thank you Mr. Doe! We are committed to supporting every student’s academic success.',
        respondedById: oakAdminUser.id,
        respondedByName: 'Marcus Sterling (Principal Office)',
        respondedAt: new Date(),
      },
      {
        schoolId: oakridgeSchool.id,
        submitterId: parentUser.id,
        targetType: 'TRANSPORT',
        targetName: 'School Bus Route 14',
        category: 'TRANSPORT',
        title: 'Bus Route 14 Morning Timing Delay',
        content: 'The bus has arrived 15 minutes late over the past two days near Central Park stop. Please check traffic scheduling.',
        rating: 3,
        isAnonymous: false,
        status: 'UNDER_REVIEW',
        response: 'Transport supervisor has been alerted and driver route re-sequenced to avoid road construction bottlenecks.',
        respondedById: officeUser.id,
        respondedByName: 'Eleanor Pence (Transport Desk)',
        respondedAt: new Date(),
      },
    ],
  });

  // 19. Seed Reminders & Tasks
  console.log('⏰ Seeding reminders and tasks...');
  await prisma.reminder.createMany({
    data: [
      {
        schoolId: oakridgeSchool.id,
        userId: classTeacherUser.id,
        title: 'Mark Entry Deadline for Mid-Term Exam',
        description: 'Complete mark evaluation and enter grades for Mathematics 10-A before the portal closes.',
        category: 'EXAM_MARK_ENTRY',
        priority: 'HIGH',
        dueDate: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000),
        status: 'PENDING',
      },
      {
        schoolId: oakridgeSchool.id,
        userId: parentUser.id,
        title: 'Tuition Fee Due Reminder: Term 1',
        description: 'Term 1 tuition fee payment of ₹45,000 for Alexander Doe is due in 3 days.',
        category: 'FEE_DUE',
        priority: 'HIGH',
        dueDate: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000),
        status: 'PENDING',
      },
      {
        schoolId: oakridgeSchool.id,
        userId: classTeacherUser.id,
        title: 'Attendance Condonation Review',
        description: 'Review students with attendance below 75% for condonation eligibility warning letters.',
        category: 'ATTENDANCE_LOW',
        priority: 'MEDIUM',
        dueDate: new Date(Date.now() + 4 * 24 * 60 * 60 * 1000),
        status: 'PENDING',
      },
    ],
  });

  await prisma.task.createMany({
    data: [
      {
        schoolId: oakridgeSchool.id,
        assignedToId: classTeacherUser.id,
        title: 'Submit Today’s Attendance Roster for 10-A',
        description: 'Lock daily morning attendance and mark absentees.',
        category: 'ATTENDANCE',
        priority: 'URGENT',
        dueDate: new Date(),
        actionUrl: '/attendance',
        status: 'PENDING',
      },
      {
        schoolId: oakridgeSchool.id,
        assignedToId: classTeacherUser.id,
        title: 'Review Leave Application for David Miller',
        description: 'Approve medical leave application submitted for Nov 14-15.',
        category: 'LEAVE_APPROVAL',
        priority: 'HIGH',
        dueDate: new Date(Date.now() + 24 * 60 * 60 * 1000),
        actionUrl: '/leave-requests',
        status: 'PENDING',
      },
      {
        schoolId: oakridgeSchool.id,
        assignedToId: subjectTeacherUser.id,
        title: 'Import Term 1 Physics Marks via Excel',
        description: 'Download class spreadsheet template, populate lab + theory marks, and upload.',
        category: 'MARK_ENTRY',
        priority: 'HIGH',
        dueDate: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000),
        actionUrl: '/exams',
        status: 'PENDING',
      },
      {
        schoolId: oakridgeSchool.id,
        assignedToId: parentUser.id,
        title: 'Digitally Acknowledge Field Trip Circular',
        description: 'Confirm consent for Class 10-A Science Museum visit.',
        category: 'CIRCULAR',
        priority: 'NORMAL',
        dueDate: new Date(Date.now() + 4 * 24 * 60 * 60 * 1000),
        actionUrl: '/circulars',
        status: 'PENDING',
      },
    ],
  });

  console.log('✅ Seeding completed successfully!');
}

main()
  .catch((e) => {
    console.error('❌ Seeding error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
