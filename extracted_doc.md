MULTI-TENANT SCHOOL ERP
Complete Product & Development Documentation
Flutter Web / Android / iOS • NestJS • PostgreSQL • Prisma • AWS
Version 2.0 | 31 October 2026Requirements, workflows, architecture, database, APIs, UI, security, testing and deployment.
Document control
Field
Value
Product
Multi-Tenant School ERP SaaS
Version
2.0 — updated for Flutter and commercial multi-school deployment
Clients
Flutter Web, Android and iOS
Backend
NestJS + TypeScript REST API
Database
PostgreSQL + Prisma ORM
Architecture
Modular monolith; shared database/schema with strict tenant isolation
Target users
Platform Owner, School Admin, Office, Principal, Class Teacher, Subject Teacher, Parent; optional Student
Status
Implementation baseline; validate school-specific policies before production
This is an independent product-development specification, not a verified inventory of a competitor's proprietary implementation. Confirm workflows, grading, attendance, fees, privacy and approval rules with pilot schools before coding.
Contents
1. Product vision and scope
2. Actors, roles and permissions
3. Functional modules
4. End-to-end workflows
5. Multi-tenant SaaS and subscription lifecycle
6. Screens and UX specification
7. Technology stack and architecture
8. Flutter application architecture
9. Backend architecture
10. Database model
11. REST API catalogue
12. Security and privacy
13. Notifications and integrations
14. Reports and analytics
15. Non-functional requirements
16. Development roadmap
17. Testing and acceptance criteria
18. Deployment and operations
19. Risks and decisions
Appendices: MVP checklist, environment variables, backlog
1. Product vision and scope
1.1 Vision
Build a configurable, secure, multi-tenant School ERP delivered as SaaS. Multiple schools use the same platform, while each school's users, records, academic setup, branding, configuration and subscription remain logically isolated.
1.2 Business objectives
Onboard and manage many schools from one platform.
Provide each school a branded, role-specific environment.
Centralize admissions, student lifecycle, academics, attendance, examinations, fees and parent communication.
Provide mobile access for parents and teachers and desktop workflows for school administration.
Monetize through subscriptions, plans, add-ons and renewals.
Maintain auditable access, reliable backups, data separation and support operations.
1.3 Release scope
Release
Included
Defer unless explicitly approved
MVP
Tenant onboarding, school selection/login, school setup, users/roles, students, guardians, staff, classes, subjects, attendance, timetable, homework basics, parent portal, notices, basic reports
Payroll, full accounting, biometric hardware, GPS, AI predictions
Release 2
Exams, marks, report cards, leave, fee plans, invoices, payment gateway, notifications, SaaS billing
Complex general ledger, advanced LMS authoring
Release 3
Transport, library, advanced analytics, custom reports, multi-branch and integrations
One-off custom features without product review
1.4 Principles
Tenant isolation is a security requirement, not merely a UI filter.
Backend is the source of truth for permissions and business rules.
One user identity may have memberships in multiple schools.
Preserve academic and financial history; do not hard-delete referenced records.
Make school-specific policies configurable.
Start with a modular monolith; split services only when scale justifies it.
2. Actors, roles and permissions
Role
Scope
Responsibilities
SaaS Platform Owner
All tenants / platform control plane
School onboarding, plans, subscriptions, billing, support, platform analytics and audited support access
School Admin / Owner
One school
School profile, users, roles, academic setup, permissions and configuration
Management / Office
One school; permitted modules
Admissions, student/staff records, fees, certificates and reports
Principal
Whole school
Academic monitoring, approvals, school-wide notices and reports
Class Teacher
Assigned class/section
Roster, class attendance, leave review, parent communication and student support
Subject Teacher
Assigned class/subject
Lesson planning, materials, homework, assessments and marks
Parent / Guardian
Verified linked children
View child records, attendance, timetable, homework, published results, fees and submit requests
Student (optional)
Own profile
Timetable, homework, resources, results and assignment submissions
2.1 Identity and membership model
Keep global users separate from school memberships. Model users, schools and user_school_memberships independently. A parent can belong to two schools, or a staff member can work across branches. Login authenticates identity, then establishes an active membership and tenant context.
2.2 Authorization model
RBAC permissions: student.read, student.create, attendance.mark, marks.publish, fee.refund, etc.
Tenant scope: every tenant-owned request is constrained to active school_id.
Resource scope: teachers access only assigned classes/subjects.
Relationship scope: parents access only verified linked children and permitted fields.
Approval scope: sensitive actions can require a second authorized role.
Platform support access is explicit, time-limited, reason-coded and audited.
2.3 Baseline permission matrix
Action
Platform
School Admin
Office
Principal
Class Teacher
Subject Teacher
Parent
Manage subscription
Yes
View own
No
View
No
No
No
School configuration
Platform
Yes
Limited
Approve/view
No
No
No
Create admission
Support
Yes
Yes
Approve
No
No
No
Edit student
Support
Yes
Yes
Limited
Assigned/read
Assigned/read
Correction request
Mark attendance
Support
Override audited
Correction
View
Assigned class
If configured
No
Enter marks
Support
Configure
No
Approve/view
View
Assigned subject
Published only
Publish results
Support
Configure
No
Approve
No
Submit
View published
Manage fees
Support
Configure
Yes
View
No
No
Own child/pay
School reports
Support
Yes
Permitted
Yes
Class only
Subject only
Own child only
Never rely on hiding buttons in Flutter. Every API endpoint must independently enforce permission and data scope.
3. Functional modules
3.1 Platform Owner / SaaS control plane
Register, approve, activate, suspend and close schools.
Unique school code, slug, subdomain and optional custom domain.
Subscription plans, trials, add-ons, student/staff/storage limits, renewals and grace periods.
Dashboard: active/trial schools, MRR/ARR, churn, active users, storage and support volume.
Support tickets, platform announcements, service status and audited temporary support access.
Tenant provisioning, export, retention and closure workflow.
3.2 School setup
School name, logo, address, contacts, timezone, locale, currency and terminology.
Academic years, terms, working days, holidays, periods and calendar.
Classes, sections, rooms, subjects, subject groups, grading and attendance rules.
School-specific fee heads, invoice numbering, notification templates and report-card layouts.
Optional branches with branch-level data scope.
3.3 Authentication and users
School discovery by search, code, invitation link or subdomain.
Login by email/phone/username and password; optional MFA for privileged roles.
Password reset, account activation, session expiry, refresh rotation, logout-all and login history.
Invite, activate, suspend, assign roles and scope memberships.
Bulk import with preview, validation errors and duplicate detection.
Guardian contact verification and controlled parent-account linking.
3.4 Admissions and student lifecycle
Admission form for applicant, guardians, previous school and required documents.
States: Draft, Submitted, Under Review, Approved, Rejected, Enrolled, Withdrawn.
Generate admission number; create student profile and academic-year enrollment.
Transfer, withdrawal, alumni/archive, promotion and retention with history.
Private document uploads with file type/size validation.
3.5 Staff and teacher management
Staff profile, employee number, designation, department, qualifications and joining date.
Link staff to user identity; configure class/subject assignments and availability.
Optional staff attendance and leave.
Restrict HR-sensitive fields to authorized roles.
3.6 Class, section and subject
Create grade/class and sections by academic year.
Map compulsory/elective subjects to class and section.
Assign class teacher and subject teachers with effective dates.
Set capacity, room, periods and promotion mapping.
Archive historical structures instead of deleting referenced data.
3.7 Attendance
Daily or period-wise attendance according to school policy.
Statuses: Present, Absent, Late, Half Day, Excused/On Leave; configurable.
Bulk mark, save draft, submit, lock and correction request.
Post-lock correction requires permission, reason and audit; optional approval.
Prevent duplicate student/session records.
Daily, monthly, term and annual summaries using configured rules.
Absence/late guardian alerts with duplicate suppression.
3.8 Timetable
Configure weekdays, periods, breaks, rooms and academic year.
Assign class, section, subject, teacher, room and period.
Detect teacher, class and room conflicts before publishing.
Substitute teacher workflow and version/effective dates.
Display applicable timetable to staff and parents.
3.9 Syllabus, lesson plans and resources
Organize subjects into units, chapters and outcomes.
Lesson plans with objectives, date, resources and completion status.
Upload PDFs, images, presentations, documents and videos.
Restrict resource access by school/class/subject.
Track planned versus completed syllabus.
3.10 Homework and assignments
Create title, instructions, audience, subject, attachments, issue/due dates and marks.
Optional student text/file submission.
States: Pending, Submitted, Late, Reviewed, Returned.
Feedback, marks, resubmission policy and overdue reports.
Notify relevant users based on preferences.
3.11 Examinations and results
Configure exam types, terms, dates, subjects, maximum/pass marks and weightages.
Enter/import marks with range validation and absent/exempt states.
Moderation and approval before publication.
Calculate totals, percentages and grades from school-approved formula.
Generate report cards; parents see published results only.
Preserve mark changes and publication history.
3.12 Fees and payments
Fee heads, class-wise plans, installments, due dates, concessions, scholarships and late fees.
Generate invoices; track due, partial, paid, overdue, cancelled and refunded.
Record offline payments and numbered receipts.
Online checkout, signed webhook verification, idempotency and reconciliation.
Refunds, waivers and invoice adjustments require reason, permission and audit.
Parent sees only linked child's fee data.
3.13 Leave management
Parent requests leave for linked child with dates/reason/document.
Route to class teacher/principal/office based on policy.
Separate staff leave workflow if enabled.
Leave must not silently overwrite attendance history.
Notify requester and preserve approval trail.
3.14 Parent portal
Child switcher for multiple linked children.
Profile, attendance, timetable, homework, resources, published results and report cards.
Invoices, payment history, receipts and online payment.
Leave application, notices, teacher communication and meeting schedule.
Limited profile correction request and notification preferences.
3.15 Communication
In-app, push, SMS and email through provider adapters.
Target by school, role, class, section, subject or recipient.
Templates, retries, quiet hours, preferences and delivery logs.
Announcement states: Draft, Approval, Scheduled, Published, Archived.
3.16 Transport (later)
Vehicles, routes, stops, driver/attendant details, capacity and student assignments.
Transport fee mapping and route rosters.
GPS only through a separately approved integration.
3.17 Library (later)
Catalogue, copies, issue, return, renewal, reservation and overdue fines.
Borrowing limits, circulation and inventory reports.
3.18 Reports and audit
Role-scoped reports with academic year, class, subject and date filters.
PDF/CSV/XLSX export with authorization and audit.
Audit login, role changes, student edits, attendance corrections, marks, payments, approvals and exports.
Large reports run in background; export files expire.
4. End-to-end workflows
4.1 School onboarding
School representative submits name, preferred code, contact and owner details.
Platform validates uniqueness and required details.
Platform Owner approves or rejects tenant.
System provisions tenant, default settings, initial School Admin membership and trial/subscription.
School Admin receives secure invitation and activates account.
School configures academic year, classes, subjects, fee settings and branding.
School imports students/staff with validation and reconciles totals.
Readiness checklist completed; tenant becomes operational.
4.2 School selection and login
Flutter app shows school search/code or resolves school from subdomain/deep link.
Client calls public tenant-discovery endpoint; receives public metadata only (name, logo, status, login methods).
User enters credentials; backend authenticates and checks active membership in selected tenant.
Backend issues short-lived access token and rotating refresh token bound to membership/tenant context.
Client calls /me to retrieve role, permissions, scopes and dashboard route.
GoRouter redirects to the correct role dashboard.
Every API request checks session, active membership, tenant, permission and resource scope.
For multi-school users, school switcher lists only verified memberships; switching establishes new tenant context and clears tenant caches.
4.3 Admission and parent linking
Office creates application and records student/guardian data.
System validates required fields and documents.
Approver accepts/rejects; approval transaction creates student and enrollment.
System assigns admission number and class/section.
Guardian contact is verified; account is invited or linked.
Parent signs in and sees only verified linked child.
4.4 Attendance to parent alert
Teacher opens assigned class/date/session.
Backend checks teacher assignment and session status.
Teacher marks attendance and submits.
Backend validates scope, duplicate rows, date and statuses; commits transaction.
Session is submitted/locked and audit event recorded.
Notification event is queued for guardians and deduplicated.
Parent portal and principal dashboard show updated authorized summary.
4.5 Timetable publication
Admin configures periods, days and rooms.
Scheduler creates timetable entries.
Backend checks class, teacher and room conflicts.
Conflicts are returned; invalid timetable cannot publish.
Authorized user publishes version with effective date.
Teachers and parents see applicable timetable.
4.6 Homework lifecycle
Subject teacher creates assignment for assigned class/subject.
Backend validates scope, dates and file access.
Notification queued to target audience.
Student submits work if enabled.
Teacher reviews, grades and returns feedback.
Parent/student sees permitted state and feedback.
4.7 Examination and result publication
Office configures exam, schedule and mark structure.
Subject teacher enters/imports marks for assigned subject/class.
Backend validates ranges, duplicates and missing statuses.
Marks move to Submitted/Moderation.
Principal or authorized reviewer approves.
Authorized user publishes results and report cards.
Parents see published results only; post-publication changes require controlled reopen.
4.8 Fee collection
Office configures fee plan and creates invoices.
Parent opens invoice and selects payment method.
Backend creates provider order/payment intent with idempotency key.
Provider processes payment and sends signed webhook.
Backend verifies signature, amount, currency, order reference and status server-to-server.
Payment is recorded once; invoice balance recalculated transactionally.
Receipt generated; office reconciles settlement.
4.9 Leave request
Parent selects child, dates and reason.
Backend verifies guardian relationship and policy.
Request routes to teacher/principal/office.
Approver accepts/rejects with remark.
Parent receives decision; audit is retained.
Attendance handling follows explicit policy without erasing original event.
4.10 Subscription renewal/suspension
Billing service calculates renewal and creates subscription invoice.
School owner receives reminder.
Verified payment changes subscription to Active.
If unpaid, tenant enters configured grace period with reminders.
After grace period, access becomes read-only or suspended according to contract; data is not deleted.
Verified payment or authorized override reactivates tenant.
5. Multi-tenant SaaS and subscription lifecycle
Tenant state
Meaning
Transitions
Pending
Registration awaiting review
Trial/Active, Rejected
Trial
Provisioned trial tenant
Active, Expired, Suspended
Active
Paid/authorized tenant
Past Due, Cancelled, Suspended
Past Due
Renewal payment outstanding
Active, Suspended
Suspended
Access restricted by policy
Active, Closed
Cancelled
Subscription ended; export/retention window applies
Reactivated, Closed
Closed
Closure completed after policy checks
No normal transition
5.1 Subscription plan fields
Field
Description
plan_code/name
Stable plan identifier and display name
billing_interval
Monthly, annual or custom
price_minor/currency
Price in minor currency unit and ISO currency
student_limit/staff_limit
Maximum active students and staff
storage_limit_bytes
Storage allowance
feature_flags
Modules and capabilities enabled
trial_days/grace_days
Trial and overdue grace periods
add_ons
SMS credits, extra storage, branches and integrations
Keep SaaS subscription billing separate from school fee collection in data model and permissions.
Use verified webhooks and idempotency for all payment state changes.
Define cancellations, refunds, tax invoices, renewals and tenant data export before launch.
Never delete school data automatically because a subscription is overdue.
6. Screens and UX specification
Area
Screen inventory
Public/discovery
Landing, school search, school code, tenant resolve, login, forgot/reset password, registration request
Platform Owner
Overview, schools, onboarding queue, tenant detail, plans, subscriptions, invoices, payments, usage, support, announcements, audit, settings
School Admin
School profile, academic year, calendar, users, roles, permissions, classes, sections, subjects, teacher allocation, branding, subscription
Office
Admissions, student list/detail, guardians, staff, fee plans, invoices, payments, receipts, certificates, exports
Principal
Overview, attendance, performance, approvals, exams, announcements, reports, calendar
Class Teacher
My class, roster, student detail, attendance, leave review, notices, parent contacts, reports
Subject Teacher
Timetable, assigned classes, syllabus, lesson plan, materials, homework, submissions, marks
Parent
Child selector, overview, profile, attendance, timetable, homework, resources, results, report cards, fees, receipts, leave, notices, messages
Shared
Profile, change password, sessions/devices, notifications, help, empty/loading/error/offline states
6.1 Flutter UX requirements
Responsive navigation: NavigationRail/Drawer on web/tablet; NavigationBar/Drawer on mobile.
Desktop tables with search, filters, pagination; mobile cards/list layouts.
Shared design system for colors, typography, spacing, forms, dialogs and feedback.
Every screen needs loading, empty, error, retry, offline and forbidden states.
Keyboard navigation, accessible labels and non-color-only status indicators.
Optimize frequent teacher workflows: select class/date, bulk mark, submit.
Do not cache sensitive data unnecessarily; secure refresh tokens using platform-appropriate storage.
7. Technology stack and architecture
Layer
Technology
Purpose
Web/mobile clients
Flutter stable + Dart
Shared product codebase for Android, iOS and web
State management
Riverpod
Testable state and dependency injection
Navigation
GoRouter
Declarative routes, deep links and guarded navigation
Networking
Dio
REST client, interceptors, timeouts and error mapping
Models
Freezed + json_serializable
Immutable DTOs and JSON serialization
Backend
NestJS + TypeScript
Domain modules, guards, services, APIs
Database
PostgreSQL
Relational records, constraints, transactions and RLS
ORM
Prisma
Typed data access and migrations
Queue/cache
Redis + BullMQ
Notifications, exports, scheduled jobs and cache
Storage
AWS S3
Private documents and report files
Push
Firebase Cloud Messaging
Mobile and supported web push
Email/SMS
Amazon SES + SMS provider
Transactional communications
Payments
Razorpay or selected provider
School fees and SaaS subscription payments
Hosting
AWS ECS/Fargate + RDS
API, worker and managed database
CI/CD
GitHub Actions
Automated checks and deployments
Monitoring
Sentry + cloud logs/metrics
Crash and operational monitoring
7.1 Logical architecture
Flutter Web / Android / iOS          | HTTPS REST   Load Balancer / API Gateway          |       NestJS API  -------- Redis / BullMQ Worker          |                         |    PostgreSQL                 Email / SMS / FCM          | Private S3 storage (signed upload/download URLs)
Start with a modular monolith: one NestJS API and a separate background worker. Keep clear module boundaries. Split services only when scale, team ownership or operational needs justify it.
7.2 Environments
Environment
Purpose
Data
Local
Developer workstation
Synthetic only
Development
Shared integration
Synthetic only
Staging/UAT
School acceptance/rehearsal
Synthetic or approved masked
Production
Live operations
Real data; least privilege
8. Flutter application architecture
8.1 Recommended packages
Package
Purpose
flutter_riverpod
State management / dependency injection
go_router
Routing, deep links, guards
dio
REST requests and interceptors
freezed_annotation + build_runner
Immutable models/code generation
json_annotation + json_serializable
JSON serialization
flutter_secure_storage
Secure token storage where supported
firebase_core + firebase_messaging
Push notification integration
intl
Date, number and currency formatting
file_picker / image_picker
File and image selection
fl_chart
Dashboard charts
cached_network_image
Image caching
connectivity_plus
Connectivity awareness, not proof of internet reachability
flutter_local_notifications
Local notification display
8.2 Feature-first folder structure
school_erp/  lib/    app/             # bootstrap, app, router, theme    core/            # config, errors, network, auth, tenant,                     # storage, permissions, shared widgets    features/      school_discovery/      authentication/      platform_admin/      school_admin/      management/      principal/      class_teacher/      subject_teacher/      parent/      admissions/      students/      staff/      academics/      attendance/      timetable/      assignments/      examinations/      fees/      leave/      notifications/      reports/    shared/          # common models, widgets, validators  test/  integration_test/  pubspec.yaml
8.3 Feature module convention
features/attendance/  data/    datasources/attendance_api.dart    models/attendance_dto.dart    repositories/attendance_repository_impl.dart  domain/    entities/attendance_record.dart    repositories/attendance_repository.dart    usecases/submit_attendance.dart  presentation/    providers/attendance_providers.dart    screens/attendance_screen.dart    widgets/attendance_status_chip.dart
8.4 Flutter tenant/session rules
Keep active tenant membership in app-level state, but backend independently verifies it.
On school switch, clear tenant-scoped caches/providers and reload /me, permissions and navigation.
Client role values control presentation only; they do not authorize data access.
Dio interceptors attach credentials and request IDs; never log passwords/tokens or sensitive student data.
Use server-side filtering and pagination; do not download every student record.
Flutter Web browser storage has XSS exposure; choose a secure session strategy and test it.
Test every plugin for web compatibility before relying on it in shared code.
8.5 Responsive UI
Platform Owner, School Admin and Office: desktop-first web with mobile fallback.
Principal: responsive web and optional mobile overview.
Teachers: responsive web and mobile app for attendance and class work.
Parents: mobile-first Android/iOS and accessible web portal.
9. Backend architecture
9.1 NestJS modules
platform
tenants
tenant-discovery
subscriptions
billing
auth
users
memberships
roles-permissions
school-settings
academic-years
admissions
students
guardians
staff
classes-sections
subjects
teacher-assignments
attendance
timetable
lessons-resources
assignments
examinations
marks-results
fees-payments
leave
announcements
notifications
reports-exports
files
audit
integrations
9.2 Request pipeline
Request -> request ID / structured logging -> rate limiting -> authentication guard -> active tenant membership resolver -> permission guard -> resource-scope check in service/repository -> DTO validation -> business transaction -> audit/outbox event -> response
9.3 Backend rules
Validate DTOs at API boundary using class-validator or Zod.
Use guards for authentication/coarse permissions; enforce row/resource scope in services too.
Use DB transactions for admissions, enrollment, marks publication, invoices and payments.
Use version-controlled Prisma migrations; never edit production schema manually.
Use transactional outbox for critical events so DB writes and notifications cannot drift.
Generate OpenAPI/Swagger documentation and version APIs under /api/v1.
10. Database model
Use UUID primary keys, timestamps, foreign keys and explicit school_id on every tenant-owned table. Include school_id in unique constraints/indexes. Store money as integer minor units or DECIMAL, never floating point. Preserve history with status/effective dates.
Table
Key fields / purpose
schools
id, code, name, slug, status, timezone, locale — tenant root
school_domains
school_id, domain, verified_at — custom domains
subscription_plans
code, price_minor, currency, interval, limits, features
subscriptions
school_id, plan_id, status, starts_at, ends_at, provider_ref
users
email, phone, password_hash, status — global identity
user_school_memberships
user_id, school_id, status — unique user/school
roles / permissions
role catalogue and permission catalogue
membership_roles
membership_id, role_id
role_permissions
role_id, permission_id
membership_scopes
membership_id, class_id?, subject_id?, branch_id?
students
school_id, admission_no, name, dob, status
guardians
school_id, user_id?, name, phone, email
student_guardians
student_id, guardian_id, relationship, access_flags
academic_years
school_id, name, start_date, end_date, status
classes / sections
school_id, grade/class and section structures
enrollments
student_id, academic_year_id, section_id, status
subjects / class_subjects
subject catalogue and year/class subject offering
staff / teacher_assignments
employee data and teaching scope
attendance_sessions
school_id, section_id, date, session_key, status
attendance_records
session_id, student_id, status, marked_by
periods / timetable_entries
periods and class/teacher/room schedule
assignments / submissions
homework and student submissions
exams / exam_subjects / marks
exam definitions, subject structure and results
fee_heads / fee_plans
fee categories and class/year fee configuration
invoices / payments
school fee demands and payment transactions
leave_requests
student leave workflow
announcements / notifications
targeted messages and delivery logs
files
school_id, owner_id, storage_key, mime_type, size, visibility
audit_logs
tenant, actor, action, entity, before/after, timestamp
devices
user_id, platform, push_token, last_seen_at
10.1 Relationships
School 1—many memberships, students, staff, academic years, classes, subjects and subscriptions.
User many—many schools through user_school_memberships.
Student many—many guardians through student_guardians.
Enrollment links student to section and academic year.
Section offers subjects through class_subjects; teacher assignments define teaching scope.
Attendance session 1—many attendance records; unique session/student.
Exam subject 1—many marks; unique exam_subject/student.
Invoice 1—many payments; balance derived from valid payments and adjustments.
10.2 Tenant isolation strategy
Recommended starting model: shared PostgreSQL database and shared schema with school_id columns, composite constraints/indexes and PostgreSQL Row-Level Security (RLS) as defense in depth. Every request must set tenant context transaction-locally. Use an application DB role that does not own protected tables and cannot BYPASSRLS. Test pooled connection behavior so context cannot leak. Prisma may require parameterized raw SQL or transaction-scoped session settings to establish RLS context safely.
10.3 Critical constraints
Unique (school_id, admission_no).
Unique (school_id, session_id, student_id) for attendance.
Unique (school_id, exam_subject_id, student_id) for marks.
Unique invoice number within school and defined period.
Unique payment provider reference/idempotency key where applicable.
Prevent cross-tenant foreign-key relationships using composite constraints where practical.
Never trust school_id supplied by the browser as proof of access.
11. REST API catalogue
Base path: /api/v1. JSON over HTTPS. Protected endpoints require authenticated session and active tenant membership. Only tenant discovery, login and verified payment webhooks are public/externally authenticated.
Method
Endpoint
Permission / purpose
GET
/tenant-discovery?query=
Public; public school metadata only
GET
/tenants/resolve/:code
Public tenant resolution
POST
/auth/login
Authenticate identity for selected tenant
POST
/auth/refresh
Rotate refresh token
POST
/auth/logout
Revoke session
GET
/me
Identity, membership, roles, permissions and scopes
POST
/me/switch-school
Switch to verified membership
POST
/platform/schools
Platform owner creates/onboards tenant
GET/PATCH
/platform/schools/:id
Platform tenant administration
GET/POST
/students
student.read / student.create
GET/PATCH
/students/:id
student.read / student.update
POST
/admissions
admission.create
POST
/admissions/:id/approve
admission.approve
GET/POST
/classes
class.read / class.manage
GET/POST
/subjects
subject.read / subject.manage
POST
/attendance/sessions
attendance.mark
POST
/attendance/sessions/:id/submit
attendance.submit
POST
/attendance/:id/correction-request
attendance.correct
GET
/attendance/reports
attendance.report
GET/POST
/timetable/entries
timetable.read / timetable.manage
POST
/timetable/publish
timetable.publish
GET/POST
/assignments
assignment.read / assignment.create
POST
/assignments/:id/submissions
submission.create
POST
/exams/:id/marks/import
marks.import
POST
/exams/:id/submit-marks
marks.submit
POST
/exams/:id/approve
results.approve
POST
/exams/:id/publish
results.publish
GET
/students/:id/report-card
report_card.read
GET/POST
/fee-plans
fee_plan.read / fee_plan.manage
POST
/invoices/generate
invoice.create
POST
/payments/checkout
payment.create
POST
/webhooks/payment-provider
Verify provider signature
POST
/leave-requests
leave.create
POST
/leave-requests/:id/decision
leave.approve
GET/POST
/announcements
announcement.read / announcement.create
GET
/reports/:key
report.run
GET
/audit-logs
audit.read
11.1 Response convention
Success:{ "data": { "id": "uuid", "status": "PRESENT" },  "meta": { "requestId": "req_abc", "nextCursor": null } }Error:{ "error": { "code": "FORBIDDEN",  "message": "Access denied", "requestId": "req_abc" } }
Paginate lists and cap page size.
Use ISO 8601 timestamps with explicit school timezone rules.
Validate every request DTO and uploaded file.
Use idempotency keys for payment and retry-prone writes.
Do not expose stack traces or database details.
Apply same tenant/resource scope to exports as screen views.
Redact credentials and personal data from logs.
12. Security, privacy and tenant isolation
12.1 Security controls
TLS everywhere; secure headers and strict CORS allowlists.
Argon2id/bcrypt password hashing; MFA for privileged roles where feasible.
Short-lived access tokens and rotating/revocable refresh tokens.
Secure mobile token storage; carefully designed browser session strategy.
Authentication, tenant, permission and resource checks on every protected request.
PostgreSQL RLS plus application scope; least-privilege DB account.
Rate limits and brute-force protection for login/reset.
Private S3, signed URLs, file limits and malware scanning.
Payment webhook signature verification and reconciliation.
Audit role changes, exports, marks, attendance corrections, refunds and support access.
Secrets manager, dependency scanning, SAST and patch process.
12.2 Privacy
Collect only necessary student/guardian data.
Document purpose and access rights for sensitive fields.
Verify guardian relationships; allow multiple guardians with explicit access flags.
Define retention, correction, export, deletion/anonymization and tenant closure policies.
Use synthetic development data and masked test datasets.
Review applicable Indian privacy, child-data, education and payment obligations with qualified counsel before launch.
12.3 Mandatory cross-tenant tests
School A cannot read School B student by guessing UUID.
School A cannot modify School B attendance by altering request IDs.
Parent cannot access unlinked child.
Teacher cannot access unassigned class/subject.
School switch clears old tenant caches and refreshes permissions.
Pooled DB connection cannot retain previous tenant RLS context.
Platform support access is time-limited, justified and audited.
13. Notifications and integrations
Event
Recipient
Channel / rule
Student absent/late
Verified guardian
In-app/push/SMS; configurable and deduplicated
New homework
Target class/guardians
In-app/push; audience checked
Assignment due
Target students/guardians
Scheduled reminder
Result published
Verified guardian
Only after approval/publication
Fee due
Payer/guardian
Configured reminder/preferences
Leave decision
Requester
In-app/push/email
Emergency notice
Selected audience
Authorized role, confirmation and delivery report
Subscription renewal
School owner
Email/in-app reminder and invoice
Payment provider: separate products/ledger for school fee payments and SaaS subscription billing.
FCM: register/revoke device tokens; handle token refresh and logout.
Email/SMS: provider adapter, retries, delivery logs, rate limits and templates.
S3: private buckets, signed URLs and lifecycle rules.
Optional calendar/identity integrations require explicit school approval.
14. Reports and analytics
Report
Filters
Audience
Student strength
Year, class, section, status
Office, Principal, Admin
Daily/monthly attendance
Date, class, section, student
Teacher, Principal; parent own child
Low attendance
Threshold, year, class
Principal, authorized Office
Exam performance
Exam, class, subject, student
Teacher, Principal; parent published only
Syllabus coverage
Subject, teacher, unit
Teacher, Principal
Assignment completion
Class, subject, due date
Teacher
Fee collection/outstanding
Date, fee head, class, due age
Office, authorized Management
Teacher workload
Teacher, class, subject, periods
Principal
Tenant usage
Active users, students, storage, API use
Platform Owner; school own usage
Subscription revenue
Plan, renewal, payment state
Platform Owner
Exports containing personal/financial data must be permission-checked, logged, time-limited and expire automatically. Large reports should run as background jobs.
15. Non-functional requirements
Area
Target / requirement
Performance
Common API reads p95 <2.5 sec at agreed pilot load; heavy reports async
Availability
Initial target 99.5% monthly after stabilization; publish maintenance windows
Scalability
Stateless API, managed DB, indexes, queues and horizontal scale
Security
No unresolved critical/high findings before production
Tenant isolation
No cross-tenant access in automated negative tests; RLS defense in depth
Accessibility
Aim for WCAG 2.2 AA for core Flutter web workflows
Compatibility
Current stable Android/iOS and supported desktop/mobile browsers
Reliability
Automated backups, restore tests, idempotent jobs and transactions
Maintainability
Typed code, linting, modular domains, API docs, migrations and tests
Localization
Configurable language, timezone, date, currency and terminology
16. Development roadmap and deliverables
Indicative plan for a small team; a production-grade commercial ERP may take longer. Build complete end-to-end workflows rather than disconnected screens.
Phase
Work
Deliverable / exit gate
0 Discovery
Pilot interviews, policy decisions, scope and workflow maps
Approved MVP scope, role matrix and acceptance criteria
1 Architecture
Tenant model, threat model, schema, API contracts, design system
ERD, RLS plan, architecture decisions, wireframes
2 Foundation
Flutter/NestJS skeleton, DB, CI, environments, auth
Login and tenant isolation tests pass
3 SaaS control plane
School registration, approval, provisioning, plans
Tenant lifecycle works
4 School setup
Academic year, classes, sections, subjects, users, roles
School Admin can configure tenant
5 Core records
Admissions, students, guardians, staff, assignments/imports
Validated records and parent linking
6 Attendance/timetable
Attendance, corrections, reports, conflict checks
Teacher-to-parent attendance flow passes
7 Academics
Homework, resources, exams, marks, approval, report cards
Published result flow passes
8 Fees/communication
Fee plans, invoices, payments, leave, notifications
Payment sandbox and retry tests pass
9 SaaS billing
Subscription invoices, renewals, grace and suspension
Subscription lifecycle passes
10 Hardening
Security, performance, accessibility, backups, UAT
No critical/high issues; school sign-off
11 Launch
Migration, training, deployment and support
Go-live checklist signed
16.1 Sprint practice
Use 1–2 week sprints with a working demo.
Prioritize vertical workflows: teacher marks attendance → backend saves → parent sees it → alert queued → principal report updates.
Every backlog item needs user, trigger, result, permission, dependencies and acceptance criteria.
Reserve sprint capacity for tests, security review and documentation.
16.2 Team roles
Role
Responsibility
Product owner / school advisor
Policy, priorities, UAT and customer feedback
Flutter developer
Responsive screens, state, navigation and API integration
Backend developer
Domain logic, API, tenant scope, DB and integrations
QA engineer
API, Flutter, tenant isolation, regression and acceptance tests
DevOps/cloud
CI/CD, AWS, secrets, monitoring, backups and incident readiness
UX designer
Role journeys, wireframes, accessibility and design system
17. Testing and acceptance criteria
17.1 Test layers
Dart unit/widget tests for validators, state and UI behavior.
NestJS unit tests for business rules, guards and services.
API integration tests against PostgreSQL including RLS behavior.
E2E workflows: onboarding, login, attendance, exams, fees, subscription and school switching.
Cross-tenant negative tests for every tenant-owned module.
Security tests: IDOR, privilege escalation, injection, sessions and file access.
Performance tests for login, student search, attendance and reports.
Backup restoration and disaster recovery drills.
17.2 Acceptance test catalogue
ID
Expected result
TEN-01
Platform Owner creates tenant and initial admin; school code unique.
TEN-02
Tenant A cannot retrieve Tenant B records by guessing IDs or altering payload.
AUTH-01
User signs in only with active membership in selected school.
AUTH-02
Multi-school user switches only to verified membership.
AUTH-03
School switch clears tenant cache and refreshes permissions.
ADM-01
Admission approval creates one student/enrollment without duplicates.
PAR-01
Parent sees only verified linked children and allowed fields.
ATT-01
Teacher marks only assigned class/session.
ATT-02
Repeated attendance submission creates no duplicates.
ATT-03
Post-lock correction requires reason, permission and audit.
TIM-01
Timetable cannot publish with teacher/class/room clash.
HW-01
Teacher creates assignment only for assigned subject/class.
EXM-01
Invalid marks rejected; unpublished results hidden from parents.
FEE-01
Invalid payment webhook signature rejected.
FEE-02
Repeated webhook does not double-credit invoice.
SUB-01
Past-due subscription follows grace/suspension policy without deleting data.
AUD-01
Sensitive action records actor, tenant, action, entity and timestamp.
EXP-01
Exports enforce same tenant and row-level permissions as UI.
17.3 Definition of done
Acceptance criteria pass in CI or signed UAT.
No unresolved critical/high security defects.
Server-side permission and tenant tests included.
Loading, empty, error, retry and success states implemented.
Audit and monitoring added for sensitive workflows.
API/user documentation updated and code reviewed.
18. Deployment and operations
Component
Suggested deployment
Flutter Web
Static build served via CDN/CloudFront
Flutter Android/iOS
Google Play and Apple App Store pipelines
NestJS API
Containerized service on ECS/Fargate or equivalent
Worker
Separate NestJS/BullMQ worker container
PostgreSQL
Managed RDS, private subnet, backups and monitoring
Redis
Managed Redis/ElastiCache
Files
Private S3 bucket, encryption and lifecycle policy
Secrets
AWS Secrets Manager or equivalent
Observability
Cloud logs/metrics, Sentry and uptime monitoring
18.1 Production release checklist
Staging UAT sign-off and release notes approved.
Database migration rehearsed; pre-release backup and rollback plan ready.
Secrets, TLS, CORS, domains and webhook URLs checked.
Deploy API/worker and Flutter web; mobile releases handled separately.
Smoke test discovery, login, tenant switch, attendance, parent view and payment if enabled.
Verify notification queues, payment webhooks, monitoring and alerts.
Confirm backups and restoration procedure.
Communicate release and support contacts to pilot schools.
18.2 Backup and recovery
Agree RPO and RTO with customers. Use automated database backups and point-in-time recovery where available, encrypted copies separated from production, object versioning/lifecycle rules and quarterly restore drills. A backup that has never been restored is not a proven recovery plan.
18.3 Operations
Define support hours, severity levels and contractual response targets.
Monitor API errors, DB saturation, queue failures, payment callbacks, SMS delivery and storage.
Review privileged accounts and school memberships periodically.
Maintain incident response, breach escalation and customer communication procedures.
Use feature flags and staged rollout for risky changes.
19. Risks and decisions before development
Decision / risk
Why it matters
Action
Single school vs school group
Tenant/branch hierarchy
Decide branch requirement for MVP
Identity uniqueness
User may belong to multiple schools
Agree email/phone uniqueness and school switching
Tenant data isolation
Cross-school leak is severe
Approve RLS design and threat model
Attendance policy
Daily/period, late, leave and correction differ
Document pilot rules
Grading model
Boards and schools differ
Make grading configurable
Fees/tax/invoices
Financially sensitive
School accountant/legal review
Guardian access
Multiple guardians may have different rights
Define verification and access flags
Flutter web fit
Dense admin tables need testing
Prototype web data tables/forms early
Data migration
Legacy data may be dirty
Profile, map, reconcile and sign off
Privacy/compliance
Student data is sensitive
Legal review, notices, retention and incident process
Commercial model
Plans/support/SLA affect cost
Define pricing and service terms
19.1 Decisions requiring sign-off
Monthly/annual plans, trial, grace and suspension behavior.
School search, code, subdomain and custom domain support.
Whether one identity can belong to multiple schools.
Whether student login is in MVP.
Daily or period attendance and approval rules.
Curriculum, grading, report card and promotion rules.
Payment provider for school fees and SaaS subscription.
Retention, export, tenant closure and support access policy.
Appendix A. MVP checklist
☐ Tenant registration, approval and provisioning
☐ School discovery and school selection
☐ Authentication, memberships and school switching
☐ Platform Owner dashboard
☐ School Admin dashboard and settings
☐ RBAC, scopes and RLS tests
☐ Academic year, classes, sections and subjects
☐ Admissions, students, guardians and staff
☐ Teacher assignments
☐ Attendance and correction audit
☐ Timetable and conflict validation
☐ Parent portal: attendance, timetable, notices
☐ Homework and basic resources
☐ Basic reports and exports
☐ Audit logs, backups and monitoring
☐ UAT and production launch
Appendix B. Example environment variables
# APINODE_ENV=PORT=DATABASE_URL=REDIS_URL=JWT_ACCESS_SECRET=JWT_REFRESH_SECRET=APP_WEB_URL=CORS_ALLOWED_ORIGINS=# StorageAWS_REGION=AWS_S3_BUCKET=# NotificationsFCM_PROJECT_ID=FCM_SERVICE_ACCOUNT_JSON=EMAIL_PROVIDER_API_KEY=SMS_PROVIDER_API_KEY=# Payments (keep fee and SaaS billing logically separate)RAZORPAY_KEY_ID=RAZORPAY_KEY_SECRET=RAZORPAY_WEBHOOK_SECRET=# MonitoringSENTRY_DSN=LOG_LEVEL=
Never commit real .env files or credentials. Use separate secrets for each environment and rotate exposed credentials immediately.
Appendix C. First 20 engineering tasks
Create Git repository, branch strategy and CI checks.
Create NestJS API and Flutter app skeletons.
Provision local PostgreSQL and Redis with Docker Compose.
Document tenant threat model and architecture decisions.
Create Prisma schema for schools, users, memberships, roles and permissions.
Implement public tenant discovery endpoint.
Implement login, refresh rotation, logout and session revocation.
Implement active membership resolution and school switching.
Implement RLS policies and cross-tenant tests.
Build Flutter school search/code and login screens.
Build role-aware route guards and dashboard shell.
Implement school onboarding and initial admin invitation.
Implement academic year, classes, sections and subjects.
Implement student, guardian and staff CRUD/import validation.
Implement teacher assignment and class roster.
Implement attendance submission, lock and correction workflow.
Build parent attendance view and absence notification event.
Implement timetable CRUD and conflict detection.
Add homework/resources and parent notice view.
Run pilot UAT, security review, restore test and production readiness gate.
END OF DEVELOPMENT SPECIFICATION