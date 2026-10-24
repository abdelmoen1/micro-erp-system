import { arCount } from "./format";

// Platform owner screens: the two separate store states, each with its own words and badge.

export const ACCESS = {
  active: { label: "الحساب مفعّل", badge: "active" },
  suspended: { label: "الحساب موقوف", badge: "inactive" },
};

/** `state` from the API: active | expired | inactive (an expiry in the past reads as expired). */
export const SUBSCRIPTION = {
  active: { label: "اشتراك فعّال", badge: "active" },
  expired: { label: "اشتراك منتهٍ", badge: "overdue" },
  inactive: { label: "بلا اشتراك", badge: "unpaid" },
};

/** "اليوم", "قبل يوم واحد", "قبل 12 يوماً". */
export function daysAgo(days) {
  if (!days) return "اليوم";
  return `قبل ${arCount(days, { one: "يوم واحد", two: "يومين", few: "أيام", many: "يوماً" })}`;
}

export const ROLE_LABEL = { owner: "مالك", manager: "مدير", employee: "موظف" };
