import {
  CanActivate,
  ExecutionContext,
  HttpException,
  HttpStatus,
  Injectable,
} from '@nestjs/common';

type RateLimitBucket = {
  count: number;
  resetAt: number;
};

const buckets = new Map<string, RateLimitBucket>();

@Injectable()
export class SimpleRateLimitGuard implements CanActivate {
  canActivate(context: ExecutionContext) {
    const request = context.switchToHttp().getRequest();
    const ip = request.ip ?? request.socket?.remoteAddress ?? 'unknown';
    const route = request.route?.path ?? request.url ?? 'unknown';
    const key = `${ip}:${route}`;
    const now = Date.now();
    const windowMs = Number(process.env.AUTH_RATE_LIMIT_WINDOW_MS ?? 60_000);
    const maxAttempts = Number(process.env.AUTH_RATE_LIMIT_MAX ?? 20);
    const current = buckets.get(key);

    if (!current || current.resetAt <= now) {
      buckets.set(key, {
        count: 1,
        resetAt: now + windowMs,
      });
      return true;
    }

    current.count += 1;

    if (current.count > maxAttempts) {
      throw new HttpException(
        'Muitas tentativas em pouco tempo. Aguarde e tente novamente.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    return true;
  }
}
