# 🎓 Linways-Grade Enterprise Multi-Tenant School ERP & AMS

[![CI/CD Pipeline](https://github.com/school-erp/school-erp/actions/workflows/ci.yml/badge.svg)](https://github.com/school-erp/school-erp/actions/workflows/ci.yml)
[![NestJS](https://img.shields.io/badge/Backend-NestJS%2011-E0234E?logo=nestjs)](https://nestjs.com/)
[![Flutter](https://img.shields.io/badge/Frontend-Flutter%203.47-02569B?logo=flutter)](https://flutter.dev/)
[![Prisma](https://img.shields.io/badge/ORM-Prisma%206-2D3748?logo=prisma)](https://prisma.io/)
[![Supabase](https://img.shields.io/badge/Database-Supabase%20Postgres-3ECF8E?logo=supabase)](https://supabase.com/)
[![Docker](https://img.shields.io/badge/Deploy-Docker%20Compose-2496ED?logo=docker)](https://docker.com/)

A production-grade, multi-tenant School and Campus Academic Management System (AMS) engineered to match the capabilities of **Linways AMS** and comprehensive ERP platforms.

Built with a high-performance **NestJS** backend, **Prisma ORM**, **Supabase PostgreSQL** relational engine, and a **Flutter Web/Mobile** design-system UI conforming to Section 11 of the ERP enterprise specification.

---

## 📑 Table of Contents

- [Key Linways AMS Features](#-key-linways-ams-features)
- [System Architecture](#-system-architecture)
- [Multi-Tenancy Model](#-multi-tenancy-model)
- [Interactive Demo Roles & Credentials](#-interactive-demo-roles--credentials)
- [API Documentation & Endpoints](#-api-documentation--endpoints)
- [Quick Start Guide](#-quick-start-guide)
- [Docker Production Deployment](#-docker-production-deployment)
- [Verification & Quality Assurance](#-verification--quality-assurance)

---

## 🌟 Key Linways AMS Features

### 1. 📖 Outcome-Based Education (OBE) & Course Delivery Plans
- **Syllabus Coverage Tracking**: Teachers define modular units, learning objectives, and planned hours.
- **Progress Meter**: Automatic calculation of overall syllabus coverage and conducted vs. planned hours.
- **Audit-Ready Logs**: Real-time status indicators (`PENDING`, `IN_PROGRESS`, `COMPLETED`).

### 2. 📝 Faculty Teaching Diary (Daily Course Log)
- **Period Execution Recording**: Logs period number, topics taught, pedagogical methodology (`LECTURE`, `LAB`, `SEMINAR`, `INTERACTIVE`), and homework assignments.
- **Teacher Accountability**: Complete institutional history of instructional delivery accessible to principals and academic coordinators.

### 3. 📚 Digital Course Repository & Study Materials
- **Institutional Knowledge Base**: Centralized repository of syllabus guides, formula cheat sheets, video resources, and textbook chapters.
- **Role-Gated Access**: Students, teachers, and parents can instantly download unit-specific materials.

### 4. ⚠️ Attendance Condonation & Shortage Risk Analytics
- **Institutional Rule Engine**: Automatically evaluates student cumulative attendance against the mandatory **75% condonation threshold**.
- **Real-Time Risk Badges**: Highlights students with `< 75%` attendance in Red alerts with condonation penalty warnings.
- **Parent Notifications**: Prominently warns parents if their child is approaching or below the condonation cut-off.

### 5. 👨‍👩‍👧 Multi-Child Parent Portal & Instant Digital Fee Checkout
- **Unified Parent Account**: Parents with children across different grades or different school campuses switch seamlessly between child profiles without logging out.
- **Interactive Fee Checkout**: Real-time fee invoices with simulated online payment (UPI, Credit Card, NetBanking).
- **Digital Tax Receipts**: Instant generation of serialized receipts (`REC-2026-00001`) with complete audit logging.

---

## 🏛 System Architecture

```mermaid
graph TD
    Client[Web Browser / Flutter Mobile App] -->|Port 8080 / 80| Nginx[Nginx Reverse Proxy / Web Server]
    Nginx -->|Static Assets| FlutterApp[Flutter Web Release WASM/JS]
    Client -->|REST API /api/v1| NestAPI[NestJS 11 Application Server]
    NestAPI -->|Tenant Interceptor & Auth Guards| Middleware[TenantContext & RBAC Shield]
    Middleware -->|Prisma Client| DB[(Supabase PostgreSQL 16)]
    NestAPI -->|Cache & Queues| Redis[(Redis 7 Cluster)]
```

### Backend Architecture
- **Framework**: [NestJS 11](file:///e:/school%20erp/backend) with TypeScript.
- **Security**: Helmet security headers, Gzip compression, JWT access & refresh token rotation, bcrypt password hashing.
- **Database**: [Prisma ORM 6](file:///e:/school%20erp/backend/prisma/schema.prisma) supporting 22 relational models with foreign keys, composite indexes, and cascade protections.
- **Error Standard**: Conformant to Section 11.1 JSON format: `{ error: { code, message, statusCode, requestId, timestamp, path } }`.

### Frontend Architecture
- **Framework**: [Flutter 3.47+](file:///e:/school%20erp/frontend) targeting Web and Mobile.
- **State Management**: Flutter Riverpod with immutable `AuthState`.
- **Styling**: `AppTheme` design system with curated indigo/slate palette, glassmorphic cards, micro-animations, and responsive shell layout.

---

## 🏢 Multi-Tenancy Model

Each school campus operates as an isolated tenant:
- **Tenant Discovery**: `/api/v1/tenant-discovery` and `/api/v1/tenants/resolve/:code`.
- **Tenant Scoping**: All requests pass the `x-school-id` header or resolve tenant via JWT active school membership.
- **Row-Level Separation**: All institutional entities (`Student`, `Staff`, `Class`, `Invoice`, `AttendanceRecord`) are strictly scoped by `schoolId`. Cross-tenant queries are blocked with `403 Forbidden` / `404 Not Found`.

---

## 👥 Interactive Demo Roles & Credentials

The application features a **1-Click Demo Profile Switcher** on the Discovery screen (`http://localhost:8080`):

| Role | Email / Login | Password | School / Scope | Primary Responsibilities |
| :--- | :--- | :--- | :--- | :--- |
| **SaaS Platform Owner** | `superadmin@erp.com` | `password123` | Global Platform | SaaS metrics, MRR/ARR, tenant provisioning |
| **School Administrator** | `admin@oakridge.edu` | `password123` | Oakridge (`OAK01`) | Class config, student roster, staff allocation |
| **Principal** | `principal@oakridge.edu` | `password123` | Oakridge (`OAK01`) | Academic oversight, exam publishing, leaves |
| **Class Teacher** | `teacher.smith@oakridge.edu` | `password123` | Oakridge (`OAK01`) | 1-Click attendance, condonation risk alerts |
| **Subject Teacher** | `teacher.jones@oakridge.edu` | `password123` | Oakridge (`OAK01`) | OBE course delivery plans, teaching diary, repository |
| **Parent (Multi-Child)** | `parent.doe@gmail.com` | `password123` | Oakridge & St. Xavier's | Multi-child switcher, attendance meter, online fee payment |

---

## 📡 API Documentation & Endpoints

OpenAPI / Swagger documentation is hosted at:
👉 **`http://localhost:3000/api/docs`**

### Summary of REST Endpoints:

| Method | Endpoint | Description | Auth Required |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/tenant-discovery` | List public school tenant directory | No |
| `GET` | `/api/v1/tenants/resolve/:code` | Resolve school details by code | No |
| `POST` | `/api/v1/auth/login` | Multi-role JWT login | No |
| `GET` | `/api/v1/auth/me` | Fetch active user profile and memberships | Yes |
| `POST` | `/api/v1/auth/switch-school` | Switch active school tenant context | Yes |
| `GET` | `/api/v1/platform/stats` | SaaS metrics & platform ARR (Superadmin only) | `PLATFORM_OWNER` |
| `GET` | `/api/v1/platform/schools` | List all provisioned school tenants | `PLATFORM_OWNER` |
| `POST` | `/api/v1/platform/schools` | Provision new tenant with admin user | `PLATFORM_OWNER` |
| `GET` | `/api/v1/academics/lesson-plans` | Linways OBE course delivery plans | Yes |
| `PATCH`| `/api/v1/academics/lesson-plans/:id/progress` | Update conducted hours & syllabus progress | Teacher/Admin |
| `GET` | `/api/v1/academics/teaching-diaries` | Faculty teaching diary logs | Yes |
| `POST` | `/api/v1/academics/teaching-diaries` | Log new instructional teaching period | Teacher |
| `GET` | `/api/v1/academics/course-materials` | Digital learning materials repository | Yes |
| `GET` | `/api/v1/academics/attendance-analytics`| `<75%` attendance condonation risk analysis | Teacher/Admin |
| `GET` | `/api/v1/students` | Scoped student roster | Yes |
| `GET` | `/api/v1/students/:id/report-card` | Academic performance report card | Yes |
| `GET` | `/api/v1/fees/invoices` | Scoped student fee invoices | Yes |
| `POST` | `/api/v1/fees/pay` | Online fee payment simulation & receipt | Yes |
| `GET` | `/api/v1/reports/overview` | Campus KPI dashboard summary | Admin/Principal |
| `GET` | `/api/v1/audit-logs` | Institutional audit trail | Admin/Principal |

---

## 🚀 Quick Start Guide

### Prerequisites
- Node.js 20+ & npm
- Flutter SDK 3.47+
- (Optional) Docker & Docker Compose

### 1. Backend Setup
```bash
cd backend
npm install --legacy-peer-deps

# 1. Configure Supabase database credentials in backend/.env:
#    DATABASE_URL="postgresql://postgres.[REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres?pgbouncer=true"
#    DIRECT_URL="postgresql://postgres.[REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:5432/postgres"

# 2. Generate Prisma Client
npm run prisma:generate

# 3. Push schema to Supabase PostgreSQL and seed demo data
npm run prisma:push
npm run seed

# 4. Start NestJS REST API
npm run start
```
API runs at `http://localhost:3000/api/v1`.

### 2. Frontend Web Setup
```bash
cd frontend
flutter pub get
flutter run -d chrome --web-port=8080
```
Or serve the release build:
```bash
python -m http.server 8080 -d build/web
```

---

## 🐳 Docker Production Deployment

Run the complete multi-container stack (PostgreSQL + Redis + NestJS API + Nginx Flutter Web) with one command:

```bash
docker-compose up --build -d
```

- **Frontend App**: `http://localhost:80`
- **Backend API**: `http://localhost:3000/api/v1`
- **Swagger Docs**: `http://localhost:3000/api/docs`

---

## 🧪 Verification & Quality Assurance

### Run Backend Linways E2E Test Suite (19 Suites)
```bash
cd backend
npx ts-node test-linways-api.ts
```
Expected output:
```
Total Tests Run : 19
Passed          : 19
Failed          : 0
Success Rate    : 100.0%
🏆 ALL E2E AND LINWAYS AMS SUITES PASSED FLAWLESSLY!
```

### Run Frontend Unit & Widget Tests
```bash
cd frontend
flutter test
```
Expected output:
```
00:01 +2: All tests passed!
```
#   s c h o o l - e r p  
 