/**
 * Short-lived cache of the user/membership/school record that JwtStrategy loads on
 * every authenticated request. With the database ~200 ms away, that lookup was
 * 3 sequential round trips per request.
 *
 * Correctness: every write that can change the outcome of token validation
 * (tokenVersion bumps, user/school status, membership role) calls
 * invalidateAuthUser()/clearAuthCache(), so revocations take effect immediately
 * in this process. If the API is ever run as several instances, a change made by
 * one instance reaches the others within AUTH_CACHE_TTL_MS at most.
 */
export const AUTH_CACHE_TTL_MS = Number(process.env.AUTH_CACHE_TTL_MS ?? 30_000);

type Entry<T> = { value: T; expiresAt: number };
const cache = new Map<string, Entry<unknown>>();
const MAX_ENTRIES = 5_000;

export function getCachedAuthUser<T>(userId: string): T | undefined {
  const entry = cache.get(userId);
  if (!entry) return undefined;
  if (entry.expiresAt <= Date.now()) {
    cache.delete(userId);
    return undefined;
  }
  return entry.value as T;
}

export function setCachedAuthUser<T>(userId: string, value: T): void {
  if (AUTH_CACHE_TTL_MS <= 0) return;
  if (cache.size >= MAX_ENTRIES) {
    const oldest = cache.keys().next().value;
    if (oldest !== undefined) cache.delete(oldest);
  }
  cache.set(userId, { value, expiresAt: Date.now() + AUTH_CACHE_TTL_MS });
}

export function invalidateAuthUser(userId: string | null | undefined): void {
  if (userId) cache.delete(userId);
}

/** Drop everything (school-wide changes such as suspension). */
export function clearAuthCache(): void {
  cache.clear();
}
