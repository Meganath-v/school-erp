# Multi-stage Production Dockerfile for Ark-ERP
FROM node:22-alpine AS builder

WORKDIR /app/backend

# Copy package definitions and Prisma schema
COPY backend/package*.json ./
COPY backend/prisma ./prisma/

# Install dependencies including Prisma CLI
RUN npm install --legacy-peer-deps

# Generate Prisma Client for Linux runtime
RUN npx prisma generate

# Copy source and static assets
COPY backend/src ./src
COPY backend/tsconfig.json ./
COPY backend/public ./public

# Build NestJS production distribution
RUN npm run build

# Production Runner Stage
FROM node:22-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=10000

# Install OpenSSL required by Prisma engine
RUN apk add --no-cache openssl

COPY --from=builder /app/backend/node_modules ./node_modules
COPY --from=builder /app/backend/dist ./dist
COPY --from=builder /app/backend/public ./public
COPY --from=builder /app/backend/prisma ./prisma
COPY --from=builder /app/backend/package.json ./package.json

EXPOSE 10000

# Push database schema and start production server
CMD ["sh", "-c", "npx prisma db push && node dist/src/main.js"]

