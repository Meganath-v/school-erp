SCHOOL ERP — DETAILED WORKFLOW SPECIFICATION

Version 2.1 requirements supplementFlutter Web / Android / iOS • NestJS • PostgreSQL

Clarified role-based login, student-parent mapping, class hierarchy, leave approvals, assessments, fees, receipts, announcements and notifications.

1. Product operating model

This supplement defines the school-level operating workflows requested for the multi-tenant School ERP. Use it together with the main Complete Product & Development Documentation. Each school is a tenant. Each tenant has its own users, academic structure, student records, fee configuration, announcements and subscription. All access is enforced by the backend.

1.1 Separate login portals

Portal

Provisioning

Scope after authentication

Platform Owner

SaaS operator creates secure account

All tenants, plans, subscriptions, billing, support and platform audit

School Admin

Platform Owner creates initial account; school admin invites authorized staff

School configuration, users, role assignment, class/parent mapping and school-wide administration

Office / Management

School Admin invites and grants permissions

Admissions, student records, fee allocation/collection, receipts and permitted reports

Principal

School Admin assigns Principal role

School-wide academic overview, approvals, announcements and reports

Class Teacher

School Admin assigns staff member to class/section

Assigned class roster, attendance, leave approvals, class announcements and class-level reports

Subject Teacher

School Admin assigns staff member to class-subject

Assigned subject/classes, homework, assessments and marks entry

Parent / Guardian

School Admin/Office creates/invites account and links verified student

Only linked child/children: attendance, leave, assessments, published results, fees, receipts and notices

Portals may have separate URLs or login screens, but use one identity/authentication service. The selected portal is not proof of authorization. The backend determines actual roles and scope from active school membership and assignments. If a user has multiple roles or schools, show only authorized choices after login.

2. Hierarchy and data relationships

Required hierarchy:

SaaS Platform → School/Tenant → Academic Year → Class/Grade → Section → Class Teacher + Enrolled Students → Verified Parent/Guardian linksSection → Subjects → Assigned Subject Teachers

Every class and section belongs to a school and academic year.

Students belong to a section through an enrollment record. Do not overwrite a student's class field during promotion; preserve historical enrollments.

Class teacher assignment includes school_id, academic_year_id, section_id, staff_id, primary flag, effective dates and status.

Subject teacher assignment links a staff member to a specific class-subject offering and effective period.

One student can have multiple verified guardians; one guardian can be linked to multiple children.

Class teachers see only their currently assigned section. Subject teachers see only assigned class-subjects. Principal and explicitly authorized admins may have school-wide scope.

All mapping changes are effective-dated and audited. Reassignment must not change historical attendance or marks attribution.

3. Student and parent account creation

Admin/Office creates or imports student with admission number, name, academic year, class and section.

Admin creates/selects guardian record, captures relationship and contact details, and verifies phone/email using OTP or approved verification.

Admin links one or more students to the guardian and sets access flags: primary guardian, fee payer, can view results, can apply leave and academic notifications.

System creates an invitation or links an existing global user identity. Send one-time activation link/OTP; do not send plain-text passwords.

Parent activates account and sees only verified linked children. A child selector is shown when multiple children are linked.

If a guardian has children in multiple schools, school switcher shows only active verified memberships.

Revoking a guardian relationship requires reason and audit and immediately removes access and future notifications.

3.1 Class teacher assignment workflow

Admin creates academic year, class and section.

Admin assigns one or more class teachers and optionally designates a primary teacher.

Teacher's My Class page displays only assigned sections and enrolled student roster.

Class teacher can mark class attendance, review leave, send class-only announcements and view class reports.

Class teacher cannot view unrelated classes, school-wide fee ledgers or unassigned subject marks unless separately granted.

At year rollover, assignments expire or renew explicitly; old year records remain unchanged.

4. Parent leave application and class teacher approval

Step

Actor

System behavior

1 Apply

Parent

Select linked child, leave dates, reason and optional document; submit.

2 Validate

Backend

Verify guardian-child link, date rules, overlapping requests and school policy.

3 Route

Backend

Send to assigned class teacher; escalate to Principal/Office if teacher unavailable or policy requires.

4 Decide

Class Teacher

Approve, reject or request more information with remark; only assigned class.

5 Notify

System

Notify parent; record actor, timestamp, decision and reason.

6 Attendance

System/authorized staff

Apply configured attendance treatment; do not silently overwrite locked attendance.

7 Escalate

Principal/Office

Handle exceptions, disputes or requests outside teacher availability.

Suggested states: Draft → Submitted → Under Review → Approved / Rejected / More Information Required → Cancelled (if allowed). Preserve append-only decision history.

Policy decision required: should approved leave automatically mark future attendance as Excused, or should teacher still mark attendance? Past locked attendance changes must use a separate correction process.

5. Parent portal requirements

Module

Parent features

Access rule

Child selector

Switch between linked children and view school/class

Verified active guardian links only

Profile

Basic student profile, admission no., class/section

Minimize sensitive fields

Attendance

Daily/period records, monthly summary, absent/late history

Own child only

Leave

Apply, track pending/history, cancel if allowed, view decision

Own child only

Assessments

Assessment name/type, subject, date, max marks and released feedback

Unpublished data hidden

Results

Term/exam marks, grades, report cards and publication date

Published results only

Homework

Instructions, due date, attachments and submission state

Enrolled class/assigned subjects

Timetable

Daily/weekly schedule and permitted teacher/room details

Current enrollment

Fees

School, hostel and transport invoices, dues, due dates and payment status

Authorized linked child/payer

Receipts

View/download official receipt and transaction reference

Authorized payer/child

Announcements

School-wide and class-specific notices

Audience membership

Notifications

Inbox, read/unread, preferences and history

Own account only

6. Assessments and results workflow

Authorized admin/principal configures assessment type, academic year, class/section, subject, date, maximum marks, weightage and grading rules.

Only assigned subject teacher or authorized examiner can enter marks for that class-subject.

Backend validates marks range, enrollment, duplicates and absent/exempt status.

Teacher submits marks for moderation; Principal or authorized reviewer approves if configured.

Only authorized role publishes marks/results. Parent cannot view draft, submitted or moderated-but-unpublished data.

After publication, changes require controlled reopen, reason, before/after audit and re-publication.

Parent sees assessment schedule, subject, marks/grade, maximum marks, remarks and publication date as configured.

Grading, rounding, weightage and pass rules must be configurable per school and academic year.

7. School, hostel and transport fees

Admin/Office must allocate fees to students. Parent sees only the fee obligations assigned to linked child/payer. Keep these three fee categories distinct in the UI and reporting.

Category

Examples

Parent view

School fees

Tuition, term, admission, lab, library, activity, exam and configured charges

Invoice, installment, due date, concessions, paid amount and balance

Hostel fees

Hostel admission, boarding, mess, maintenance and configured charges

Hostel assignment, billing period, invoice and due date

Transport fees

Route, stop, transport period, one-time or recurring charge

Assigned route/stop, billing period and invoice

7.1 Fee allocation workflow

Office configures fee heads, plans, amounts, academic year, class/section eligibility, installments, due dates, late fee and concession rules.

Office allocates a plan to a student, cohort or eligible hostel/transport assignment. Individual exceptions require reason and permission.

System generates invoice with unique school invoice number, student, category, line items, payer, amount, due date and status.

Parent receives in-app/push notification and sees separate School, Hostel and Transport tabs.

Partial payment, overpayment, waiver, late fee, refund and adjustment policies are configurable and audited.

7.2 Online payment workflow

Parent selects invoice(s) and chooses Pay Online.

Backend creates payment order with provider, amount, currency, invoice references and idempotency key. Amount is calculated server-side.

Flutter opens provider checkout; ERP must not collect or store card/UPI credentials directly.

Provider sends signed webhook. Backend verifies signature, order reference, amount, currency and final status.

Payment and invoice balance update transactionally. Replayed webhooks must not credit twice.

System issues official receipt and notifies parent and office after verified success.

Pending/failed payments remain clearly labelled; status refresh/reconciliation must not cause duplicate charges.

7.3 Fee receipt contents

School name/logo/contact and unique receipt number.

Student name, admission number, class/section and payer name.

Payment date/time, fee category and invoice number.

Line-item breakdown, amount paid, remaining balance and payment mode.

Provider transaction/reference ID and receipt status.

PDF view/download and in-app receipt history; optional email/SMS delivery.

Receipt is immutable after issue. Correction uses void/reversal and replacement receipt linked by audit.

8. Announcement hierarchy

Sender

Allowed audience

Restriction

Platform Owner

All tenants or selected school admins for platform notices

Platform notices only; tenant support access audited

School Admin

Whole school, selected roles, classes, staff, parents or targeted groups

May require Principal approval by policy

Principal

Whole school, selected classes/sections, staff and parents

Within own tenant

Class Teacher

Only assigned class/section students and their verified guardians

Cannot target another class or whole school

Subject Teacher

Assigned subject/class students; guardians if enabled

Cannot target unrelated classes

Parent

No broadcast; permitted individual query/contact channel only

No access to other parents' messages

8.1 Announcement publishing workflow

Sender enters title, body, attachments, priority, audience, publish time and expiry.

Backend checks role and current class/subject assignment. Class teacher audience is derived from assigned section, not trusted from arbitrary client IDs.

Optional moderation routes draft to Principal/School Admin.

On publish, backend resolves recipients and queues notifications.

Recipients see feed item; read/unread and delivery states are tracked.

Edits/withdrawals preserve revision history; emergency broadcast has separate permission.

9. Notification feature requirements

Event

Recipient

Channel/behavior

Parent account invitation

Guardian

One-time SMS/email activation link

Student linked/class changed

Parent and relevant staff

In-app/push; audited

Absent/late attendance

Verified guardian; configured teacher

In-app/push/SMS; deduplicated

Leave submitted

Assigned class teacher

In-app/push task

Leave decision

Parent

In-app/push/email/SMS preferences

Assessment scheduled/changed

Target class students/guardians

In-app/push

Result published

Guardians of affected students

Only after publication

Homework created/due

Target class/guardians

In-app/push and scheduled reminder

Fee allocated/due/overdue

Payer/guardian; office as configured

In-app/push/email/SMS

Payment success/failure

Payer and office as configured

In-app/push; receipt only after verified success

Announcement published

Resolved audience

In-app/push; priority/expiry

Timetable/substitute change

Affected class/teachers/guardians

In-app/push

Subscription renewal

School owner/billing contact

Email/in-app

9.1 Notification architecture and controls

Central notification service with FCM, email and SMS provider adapters.

Redis/BullMQ background jobs and transactional outbox for critical events.

Store tenant, recipient, event type, channel, template version, created/sent/delivered/read state and provider reference.

Support preferences, quiet hours, language templates, priority, retry/backoff and dead-letter queue.

Deduplicate using stable event key, e.g. attendance_session_id + student_id + event_type.

Class teacher recipients derive from assigned class; parent recipients derive from verified guardian links.

Do not expose sensitive student data in push previews by default; use generic alert and require login.

In-app inbox supports read/unread, mark-all-read, deep link and archive/expiry.

Delivery reports must not expose another tenant's recipient lists.

10. Extra hierarchy-aware features

Class dashboard: roster, today's attendance, pending leave, upcoming assessments, homework and recent announcements.

Teacher workload: assigned sections/subjects, timetable, marking tasks and pending approvals.

Principal dashboard: school attendance, approvals, exam readiness, permitted fee summary and school notices.

Admin mapping console: assign/reassign class teachers, subject teachers, students to sections and guardians to students; bulk import and conflict warnings.

Guardian relationship audit: who verified, changed or revoked a link and when.

Academic-year rollover: promote students, create enrollments, renew teacher assignments and preserve previous-year records.

Substitute teacher workflow with time-bounded, limited permissions.

Escalation if assigned teacher is unavailable or leave request is pending beyond configured SLA.

Emergency contact and notification preferences, visible only to authorized staff.

Parent export of permitted child records/receipts; school exports require permission and audit.

11. Additional database entities

Entity

Fields / constraints

class_teacher_assignments

school_id, academic_year_id, section_id, staff_id, is_primary, effective_from/to, status

teacher_assignments

school_id, class_subject_id, staff_id, effective dates, status

student_guardians

school_id, student_id, guardian_id, relationship, is_primary, is_fee_payer, can_view_results, can_apply_leave, verified_at, status

parent_invitations

school_id, guardian_id, invited_contact, token_hash, expires_at, accepted_at, status

leave_requests

school_id, student_id, guardian_id, from/to dates, reason, status, current_approver_id

leave_request_events

leave_request_id, actor_id, action, note, created_at; append-only

assessments

school_id, academic_year_id, class_subject_id, type, title, date, max_marks, weightage, status

assessment_marks

school_id, assessment_id, student_id, marks, result_status, remarks, entered_by, published_at

fee_heads

school_id, category, code, name, active

fee_allocations

school_id, student/cohort, fee_head_id, period, amount_minor, due_date, payer_guardian_id, status

invoices/invoice_items

school_id, student_id, invoice_no, category, total_minor, due_date, status; line items reference fee heads

payments

school_id, invoice_id, amount_minor, provider, provider_ref, idempotency_key, status, paid_at

receipts

school_id, payment_id, receipt_no, storage_key, issued_at, status, voided_by, void_reason

announcements

school_id, sender_membership_id, audience_type/ref, title, body, status, publish_at, expires_at

announcement_recipients

announcement_id, user_id, student_id nullable, delivery/read status; recipient snapshot

notifications

school_id, recipient_user_id, event_key, channel, status, provider_ref, read_at

Use composite foreign keys or equivalent constraints to prevent a student, guardian, invoice, class or teacher assignment from referencing records belonging to different schools.

12. Additional API endpoints

Method

Endpoint

Purpose / permission

POST

/school-users/invitations

Invite user/parent; user.manage

POST

/parent-invitations/:token/accept

Accept verified invitation

POST

/students/:id/guardians

Link guardian; guardian.manage

DELETE

/students/:id/guardians/:guardianId

Revoke with reason; guardian.manage

POST

/sections/:id/class-teachers

Assign class teacher

GET

/teacher/my-classes

List assigned classes

GET

/parent/my-children

List verified linked children

POST

/leave-requests

Parent applies for leave

GET

/leave-requests/inbox

Approver inbox

POST

/leave-requests/:id/decision

Approve/reject/request information

GET/POST

/assessments

List/create assessment

POST

/assessments/:id/marks

Enter/import marks

POST

/assessments/:id/publish

Publish approved marks

GET

/parent/children/:studentId/assessments

Parent view released assessments

GET/POST

/fee-allocations

Allocate fees

POST

/invoices/generate

Generate invoices

GET

/parent/children/:studentId/fees

Parent fee ledger

POST

/payments/checkout

Create payment order

GET

/payments/:id/status

Refresh payment status safely

GET

/receipts/:id

Authorized receipt metadata/download

POST

/announcements

Create announcement; check audience permission

POST

/announcements/:id/publish

Publish after authorization

GET

/notifications

Own notification inbox

PATCH

/notifications/:id/read

Mark own notification read

PATCH

/notification-preferences

Update own preferences

13. Updated acceptance tests

ID

Expected result

MAP-01

Admin assigns class teacher to section with effective dates.

MAP-02

Teacher sees only students currently enrolled in assigned section.

MAP-03

Promotion preserves prior-year enrollment and records.

PAR-01

Admin invites guardian and links verified parent to correct student.

PAR-02

Parent switches linked children; unrelated student ID is denied.

PAR-03

Revoked guardian link removes access and future child alerts.

LEV-01

Parent leave request routes to assigned class teacher.

LEV-02

Teacher decides only requests in assigned class/date scope.

LEV-03

Parent sees decision and approval history.

LEV-04

Approved leave does not silently rewrite locked attendance.

ASM-01

Subject teacher enters marks only for assigned class-subject.

ASM-02

Parent cannot view draft/unpublished marks.

ASM-03

Published result correction is audited and controlled.

FEE-01

Office allocates school, hostel and transport fees to correct student/payer.

FEE-02

Parent sees only invoices for linked child and authorized payer scope.

FEE-03

Client cannot alter server-calculated checkout amount.

FEE-04

Invalid/replayed webhook cannot credit invoice twice.

REC-01

Verified payment generates unique receipt with category, amount and provider reference.

REC-02

Voided receipt remains auditable; replacement links to original.

ANN-01

Principal/Admin publishes school-wide notice within tenant.

ANN-02

Class teacher publishes only to assigned class/section.

ANN-03

Class teacher cannot target another class by changing API payload.

NOT-01

Absence event creates one notification per intended recipient/event.

NOT-02

User can mark own notification read, not another user's.

NOT-03

Push preview does not expose sensitive student details by default.

14. Updated implementation priority

Priority

Scope

P0 — foundation

Separate role-aware portals, tenant isolation, school selection, user provisioning, parent-child mapping, class/teacher mapping and audit

P1 — school operations

Class attendance, parent attendance view, parent leave + teacher approval, Admin/Principal school announcements, class-only teacher announcements, notification inbox

P1 — parent value

Assessments, published results, child switcher, timetable and homework

P1 — payments

Admin fee allocation for school/hostel/transport, parent online checkout, payment verification, invoice ledger and downloadable receipts

P2 — maturity

Advanced analytics, bulk import, escalation, substitute teacher, transport/library, custom reports and integrations

Recommended implementation sequence: (1) tenant + identity + membership/roles, (2) school user provisioning and parent-child links, (3) academic-year/class/section/teacher mappings, (4) parent portal, (5) leave and attendance, (6) assessments/results, (7) announcements/notifications, (8) fee allocation/payment/receipts, (9) subscription billing and production hardening.