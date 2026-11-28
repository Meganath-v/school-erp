/** Date helpers for the school-local calendar. Dates are stored as UTC midnight (`@db.Date`). */

export const TIME_RE = /^([01]\d|2[0-3]):[0-5]\d$/;
export const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

export const DAY_NAMES: Record<number, string> = {
  1: 'Monday', 2: 'Tuesday', 3: 'Wednesday', 4: 'Thursday', 5: 'Friday', 6: 'Saturday', 7: 'Sunday',
};

/** Today's date (YYYY-MM-DD) in the school's time zone. */
export function schoolToday(timeZone?: string | null, now = new Date()): string {
  try {
    return new Intl.DateTimeFormat('en-CA', { timeZone: timeZone || 'Asia/Kolkata', year: 'numeric', month: '2-digit', day: '2-digit' }).format(now);
  } catch {
    return new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kolkata', year: 'numeric', month: '2-digit', day: '2-digit' }).format(now);
  }
}

/** 'YYYY-MM-DD' → Date at UTC midnight, or null when the text is not a real date. */
export function parseDateOnly(text: string): Date | null {
  if (!DATE_RE.test(text)) return null;
  const [y, m, d] = text.split('-').map(Number);
  const date = new Date(Date.UTC(y, m - 1, d));
  return date.getUTCFullYear() === y && date.getUTCMonth() === m - 1 && date.getUTCDate() === d ? date : null;
}

export function toDateText(date: Date): string {
  return date.toISOString().slice(0, 10);
}

/** 1 = Monday … 7 = Sunday for a 'YYYY-MM-DD' date. */
export function dayOfWeekOf(text: string): number {
  const date = parseDateOnly(text);
  if (!date) return 0;
  const d = date.getUTCDay();
  return d === 0 ? 7 : d;
}

export function minutes(time: string): number {
  const [h, m] = time.split(':').map(Number);
  return h * 60 + m;
}
