import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

export interface CreateAuditLogParams {
  schoolId?: string | null;
  actorId?: string;
  actorName?: string;
  action: string;
  entity: string;
  entityId?: string | null;
  details?: Record<string, any> | string | null;
}

@Injectable()
export class AuditService {
  private readonly logger = new Logger(AuditService.name);

  constructor(private prisma: PrismaService) {}

  /**
   * Records an immutable institutional audit event with actor, action, entity, timestamp, and tenant context.
   */
  async log(params: CreateAuditLogParams, client?: any): Promise<void> {
    try {
      const detailsStr =
        typeof params.details === 'object' && params.details !== null
          ? JSON.stringify(params.details)
          : (params.details as string) || null;

      const db = client || this.prisma;
      await db.auditLog.create({
        data: {
          schoolId: params.schoolId || null,
          actorId: params.actorId || 'system',
          actorName: params.actorName || 'System',
          action: params.action,
          entity: params.entity,
          entityId: params.entityId || null,
          details: detailsStr,
        },
      });
    } catch (err: any) {
      // Never crash the primary business flow if audit write encounters a transient error
      this.logger.error(`Failed to record audit log for action "${params.action}": ${err.message}`, err.stack);
    }
  }

  /**
   * Retrieves audit logs for the specified tenant, restricted to authorized administrators.
   */
  async getAuditLogs(
    schoolId?: string | null,
    query?: { action?: string; entity?: string; search?: string; limit?: number },
  ) {
    const where: any = {};
    if (schoolId) {
      where.schoolId = schoolId;
    }
    if (query?.action && query.action !== 'ALL') {
      where.action = query.action;
    }
    if (query?.entity && query.entity !== 'ALL') {
      where.entity = query.entity;
    }
    if (query?.search && query.search.trim()) {
      const s = query.search.trim();
      where.OR = [
        { action: { contains: s, mode: 'insensitive' } },
        { entity: { contains: s, mode: 'insensitive' } },
        { actorName: { contains: s, mode: 'insensitive' } },
        { details: { contains: s, mode: 'insensitive' } },
      ];
    }

    return this.prisma.auditLog.findMany({
      where,
      orderBy: { timestamp: 'desc' },
      take: query?.limit || 100,
    });
  }
}
