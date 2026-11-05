import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;

    let message = 'An unexpected internal server error occurred';
    let code = 'INTERNAL_ERROR';

    if (exception instanceof HttpException) {
      const res = exception.getResponse();
      if (typeof res === 'string') {
        message = res;
      } else if (typeof res === 'object' && res !== null) {
        const resObj = res as Record<string, any>;
        message = Array.isArray(resObj.message) ? resObj.message.join(', ') : resObj.message || message;
        code = resObj.error || HttpStatus[status] || code;
      }
    } else if (exception instanceof Error) {
      this.logger.error(`Unhandled Exception on ${request.method} ${request.url}: ${exception.message}`, exception.stack);
    }

    const requestId = (request.headers['x-request-id'] as string) || `req_${Date.now()}`;

    response.status(status).json({
      error: {
        code,
        message,
        statusCode: status,
        requestId,
        path: request.url,
        timestamp: new Date().toISOString(),
      },
    });
  }
}
