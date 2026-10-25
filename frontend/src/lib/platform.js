import { arCount } from "./format";

// Platform owner screens: the two separate store states, each with its own words and badge.

export const ACCESS = {
  active: { label: "الحساب مفعّل", badge: "active" },
  suspended: { label: "الحساب موقوف", badge: "inactive" },
};

/** `state` from the API: active (paid) | trial | expired (paid, past its expiry) | inactive (trial over, never paid). */
export const SUBSCRIPTION = {
  active: { label: "اشتراك فعّال", badge: "active" },
  trial: { label: "فترة تجريبية", badge: "due_today" },
  expired: { label: "اشتراك منتهٍ", badge: "overdue" },
  inactive: { label: "بلا اشتراك", badge: "unpaid" },
};

/** "اليوم", "قبل يوم واحد", "قبل 12 يوماً". */
export function daysAgo(days) {
  if (!days) return "اليوم";
  return `قبل ${arCount(days, { one: "يوم واحد", two: "يومين", few: "أيام", many: "يوماً" })}`;
}

export const ROLE_LABEL = { owner: "مالك", manager: "مدير", employee: "موظف" };

/** "ينتهي اليوم", "متبقٍ يوم واحد", "متبقٍ 5 أيام" until an ISO time (whole days, rounded up). */
export function daysLeftLabel(iso) {
  const days = Math.ceil((new Date(iso).getTime() - Date.now()) / 86_400_000);
  if (days <= 1) return days <= 0 ? "انتهت" : "ينتهي خلال يوم";
  return `متبقٍ ${arCount(days, { one: "يوم واحد", two: "يومان", few: "أيام", many: "يوماً" })}`;
}
