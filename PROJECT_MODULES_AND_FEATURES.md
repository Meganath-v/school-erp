# 🏫 Multi-Tenant School ERP & Linways Academic Management System (AMS)
## Complete Project Architecture, Modules & Features Guide

---

## 📌 Executive Summary

This project is an enterprise-grade, multi-tenant **School ERP & Academic Management System (AMS / LMS / SIS)** modeled after institutional software standards (such as Linways). It provides end-to-end management for K-12 schools, colleges, and multi-campus educational institutions with strict multi-tenancy isolation, role-based access control (RBAC), and automated workflows.

### 🛠️ Technology Stack
* **Backend REST API**: NestJS 11, TypeScript 5.7, Express, Passport.js, Helmet, Compression, Throttler.
* **Database & ORM**: Prisma ORM 6.4 with multi-tenant relational schema (compatible with SQLite for embedded zero-config local dev and PostgreSQL for production).
* **Cross-Platform Client (Mobile, Tablet, Web)**: Flutter 3.47 / Dart with Riverpod state management and Material 3 design system.
* **Computer-Only Teacher Desktop Portal**: Standalone high-density web workstation built with HTML5, Tailwind CSS, SheetJS (XLSX), and Lucide Icons, served directly by the NestJS web server.

---

## 👥 System Roles & RBAC Matrix

The system enforces strict tenant and role boundaries across 8 distinct institutional user personas:

| Role Code | Institutional Persona | Scope & Core Responsibilities |
|---|---|---|
| `PLATFORM_OWNER` | SaaS System Operator | Onboards schools, manages subscription tiers, provisions tenant databases, and views global platform analytics. |
| `SCHOOL_ADMIN` | Campus Administrator | Complete administrative control over school settings, academic sessions, staff rosters, fee structures, and audit logs. |
| `OFFICE` | Office / Accounts Employee | Handles student admissions, records offline fee collections, issues serialized tax receipts, and dispatches school-wide circulars. |
| `PRINCIPAL` | Headmaster / Principal | Academic oversight, teacher workload monitoring, approves/publishes term examination results, compliance reviews. |
| `CLASS_TEACHER` | Assigned Class In-Charge | Locks daily attendance, reviews leave applications, dispatches class-specific circulars, monitors 75% attendance condonation threshold. |
| `SUBJECT_TEACHER` | Faculty / Course Teacher | Manages OBE syllabus units, logs daily teaching diary entries, issues homework, enters exam marks via spreadsheet or Excel upload. |
| `PARENT` | Parent / Legal Guardian | Views linked children's progress, checks 3-category fee ledgers (School/Hostel/Transport), signs circulars, submits feedback. |
| `STUDENT` | Enrolled Learner | Views daily timetable, downloads course study materials, checks homework assignments, reviews published report cards. |

---

## 📦 Complete Backend Modules Breakdown

```
backend/src/modules/
├── academics/          # Classes, sections, subjects, OBE lesson plans, course materials
├── announcements/      # Campus bulletins with role-based targeting
├── assignments/        # Homework creation, student submissions, evaluation
├── attendance/         # Morning & period attendance sessions, condonation calculation
├── auth/               # Multi-tenant authentication, JWT tokens, tokenVersion revocation
├── circulars/          # Formal circulars (Class Teacher & Office sent), digital sign-offs
├── exams/              # Examinations, bulk mark spreadsheets, Excel import/export, broadsheets
├── feedback/           # Parent & student feedback desk, ratings, admin resolutions
├── fees/               # 3-Category fee ledger, payment receipt serialization, office collection
├── leave/              # Student leave applications, medical notes, class teacher approval inbox
├── notifications/      # In-app notifications with read/unread statuses
├── parent/             # Linked student lookup, parent dashboard data aggregation
├── platform/           # Multi-tenant SaaS provisioning, subscription tier enforcement
├── reminders/          # Automated scan engine for fee, attendance, task, and mark deadlines
├── reports/            # Compliance reports, condonation deficiency lists, fee statistics
├── schools/            # Campus configuration, branding, domains, academic years
├── staff/              # Faculty directories, teacher-subject-section assignments
├── students/           # Student admissions, guardian relationships, enrollments
├── tasks/              # In-app actionable tasks with role-specific defaults & statistics
├── tenant-discovery/   # Tenant resolution via subdomain or school code (e.g. OAK01)
└── timetable/          # 8-period weekly schedule generator with collision detection
```

---

## 🌟 Detailed Feature Specifications

### 1. 🔔 Reminder Notifications Engine
* **Automated Trigger Scans (`POST /api/v1/reminders/trigger-automated`)**:
  * **Fee Due Reminders**: Automatically scans for unpaid invoices within 7 days of due date and dispatches in-app notifications and reminder cards to linked parents.
  * **Low Attendance Condonation Alerts**: Automatically identifies students below the 75% attendance threshold and generates alerts for both class teachers and parents.
  * **Exam Mark Deadlines**: Notifies subject teachers when marks for scheduled/in-progress examinations have not yet been submitted.
  * **Pending Leave Requests**: Alerts class teachers about pending student leave applications requiring review.
* **Custom User Reminders**: Allows faculty and staff to schedule custom deadline alerts with priority flags (`LOW`, `MEDIUM`, `HIGH`, `URGENT`).

### 2. ✅ In-App Action Tasks (`/tasks`)
* **Role-Specific Task Generation**: Automatically provides contextual action items for newly created or active accounts:
  * *Class Teacher*: "Mark Today’s Attendance", "Review Pending Student Leave Requests", "Dispatch Class Circular".
  * *Subject Teacher*: "Complete Exam Mark Entry", "Submit Weekly Teaching Diary", "Grade Homework Submissions".
  * *Office Employee*: "Send Fee Reminder Circular", "Audit Condonation Thresholds".
  * *Parent*: "Pay Term 1 Tuition Fee", "Acknowledge Annual Day Circular".
* **Task Lifecycle**: Tracks status transitions (`PENDING` $\rightarrow$ `IN_PROGRESS` $\rightarrow$ `COMPLETED`).
* **Performance Statistics**: Real-time completion rates, pending counters, and urgent item badges.

### 3. 💬 Parent & Staff Feedback Desk (`/feedback`)
* **Categorized Submissions**: Supports Academic, Infrastructure, Transport/Bus, Behavioral, General Suggestions, and Complaints.
* **Star Ratings**: 1 to 5 star evaluation scores for qualitative reporting.
* **Anonymous Option**: Parents can submit grievances anonymously (identity automatically masked for non-admin viewers).
* **Administrative Resolution**: School Administrators and Teachers can respond directly with official resolution notes, changing status to `RESOLVED` and dispatching confirmation notifications.

### 4. 📢 Circulars & Digital Sign-Offs (`/circulars`)
* **Role-Restricted Dispatch**:
  * **Class Teacher Circulars**: Strictly locked to their assigned class and section parents/students (prevents unauthorized school-wide broadcasts).
  * **Office Employee & Admin Circulars**: Campus-wide broadcasts, All Teachers, All Parents, or Office Staff.
* **Mandatory Digital Acknowledgment**: Circulars can require parental signature. Real-time report shows exactly which parents have or haven't signed, along with sign-off timestamps and parent remarks.
* **Official Numbering & Attachments**: Automated sequential numbering format (e.g. `CIR/2026/001`) with attachment link support.

### 5. 📊 Exam Marks Entry, Viewing & Excel Import/Export (`/exams`)
* **Pre-Filled Excel/CSV Template Export (`GET /exams/subjects/:id/template`)**:
  * Generates formatted templates with enrolled student names, admission numbers, roll numbers, and maximum marks pre-populated.
  * Supports both `.csv` and Microsoft Excel `.xlsx` workbook formats.
* **Bulk Marks Import (`POST /exams/subjects/:id/import`)**:
  * Parses uploaded Excel sheets or CSV files.
  * Validates every student's active enrollment in that class and school.
  * Enforces mark limits ($0 \le \text{mark} \le \text{maxMarks}$) and supports absentee flags (`Y` / `N`).
  * Atomic transactional commit ensures either all rows are valid or descriptive row-by-row error logs are returned.
* **Consolidated Class Broadsheet (`GET /exams/:id/classes/:classId/broadsheet`)**:
  * Complete matrix of all subjects across all students in a class.
  * Calculates total marks, grand percentage, letter grades (A+, A, B, C, D, F), pass/fail status, and student class rank.
* **Exam Publication Lockdown**: Once published by the Principal, exam marks become immutable and locked against tampering.

### 6. 🖥️ Computer-Only Teacher Desktop Webpage (`/teacher/index.html`)
Designed specifically for screen-intensive desktop/laptop workflows in staff rooms and computer labs:
1. **Spreadsheet-Grade Mark Entry Grid**:
   * High-speed keyboard navigation: `Tab` to advance to the next field, `Enter` / `Down Arrow` to jump to the next student.
   * Press `A` or toggle checkbox for instant absentee recording.
   * Auto-calculates percentages and letter grades live on screen.
   * `Ctrl+S` / `Cmd+S` one-click bulk database save.
2. **Drag & Drop Excel Import Wizard**:
   * Drag-and-drop Excel files directly into the browser.
   * Instant client-side SheetJS parsing with zero server lag.
   * Color-coded preview table before committing.
3. **Consolidated Class Attendance Register & Condonation Matrix**:
   * Month-long calendar register showing daily status (`P`, `A`, `L`) for all 40+ students simultaneously.
   * Highlights in red students who drop below the **75% Linways condonation threshold**.
   * One-click "Export Condonation Defaulters List" and "Send Warning Reminders".
4. **Linways OBE Syllabus & Teaching Diary**:
   * Unit-by-unit syllabus completion progress bars.
   * Lesson log entries: period number, topic, methodology (Lecture, Lab, Flipped Classroom), and observations.
5. **Print-Ready Broadsheet Studio**:
   * Full class ranking sheet formatted for immediate physical printing or PDF export.
6. **Parent Feedback Resolution Center**:
   * Read incoming parent inquiries and post instant replies.

### 7. 💰 3-Category Fee Ledger & Receipts (`/fees`)
* **Three Independent Fee Categories**:
  1. `SCHOOL` (Tuition, Library, Laboratory, Examination)
  2. `HOSTEL` (Boarding, Mess, Laundry)
  3. `TRANSPORT` (Bus Route Fleet fees)
* **Secure Payment Processing**:
  * Office Cash/Cheque collection with atomic balance adjustments and anti-overpayment validation.
  * Prevents parent client-side self-marking of unpaid invoices.
  * Generates immutable, serialized official receipts (e.g. `REC-2026-001`) with unique database constraints.

### 8. 📋 Attendance & Linways Condonation (`/attendance`)
* Supports both Daily Morning Attendance and Period-wise Attendance.
* Bulk marking capabilities: "Mark All Present" with quick absentee toggles.
* Automated attendance percentage tracking against working days.

### 9. 📚 Linways Academic Management Suite (OBE & Repository)
* **Outcome-Based Education (OBE)**: Course Outcomes (COs) mapped to Bloom’s Taxonomy levels (Remember, Understand, Apply, Analyze, Evaluate, Create).
* **Course Delivery Plans**: Planned vs conducted hours tracking.
* **Course Materials Repository**: Categorized study materials (PDFs, PPT slides, lecture videos) organized by unit.

---

## 🗄️ Relational Database Schema Overview

```mermaid
erDiagram
    School ||--o{ UserSchoolMembership : has
    School ||--o{ AcademicYear : has
    School ||--o{ Class : has
    Class ||--o{ Section : has
    Class ||--o{ Subject : has
    Section ||--o{ Enrollment : contains
    Student ||--o{ Enrollment : has
    User ||--o{ UserSchoolMembership : belongs
    User ||--o{ Staff : profile
    User ||--o{ Guardian : profile
    Student ||--o{ StudentGuardian : linked
    Guardian ||--o{ StudentGuardian : linked
    Class ||--o{ ExamSubject : tests
    Exam ||--o{ ExamSubject : includes
    ExamSubject ||--o{ Mark : scores
    Student ||--o{ Mark : receives
    School ||--o{ Invoice : issues
    Student ||--o{ Invoice : billed
    Invoice ||--o{ Payment : receives
    School ||--o{ Circular : issues
    Circular ||--o{ CircularAcknowledgement : tracks
    School ||--o{ Feedback : receives
    School ||--o{ Task : manages
    School ||--o{ Reminder : schedules
```

---

## 🔑 Demo Access Credentials

The database comes pre-seeded with full institutional demo data:

| Role | Email Login | Password | School Code |
|---|---|---|---|
| **Platform Owner** | `superadmin@erp.com` | `password123` | *None (Global)* |
| **School Admin** | `admin@oakridge.edu` | `password123` | `OAK01` |
| **Office Staff** | `office@oakridge.edu` | `password123` | `OAK01` |
| **Principal** | `principal@oakridge.edu` | `password123` | `OAK01` |
| **Class Teacher** | `teacher.smith@oakridge.edu` | `password123` | `OAK01` |
| **Subject Teacher** | `teacher.jones@oakridge.edu` | `password123` | `OAK01` |
| **Parent** | `parent.doe@gmail.com` | `password123` | `OAK01` |
| **Student** | `student.john@oakridge.edu` | `password123` | `OAK01` |

---

## 🚀 How to Run the Project

### 1. Run the Backend REST API & Teacher Workstation
```bash
cd backend
npm install --legacy-peer-deps
npx prisma generate
npm run build
node dist/src/main.js
```
* **API Endpoints**: `http://localhost:3000/api/v1`
* **Swagger OpenAPI Docs**: `http://localhost:3000/api/docs`
* **Teacher Desktop Portal**: `http://localhost:3000/teacher/index.html`

### 2. Run the Automated API Test Suite
```bash
cd backend
npx ts-node test-linways-api.ts
npx ts-node test-new-services.ts
```

### 3. Run the Flutter Cross-Platform Client
```bash
cd frontend
flutter pub get
flutter run -d chrome --web-port=8080
```
*(Or target `windows`, `edge`, or mobile emulators).*

