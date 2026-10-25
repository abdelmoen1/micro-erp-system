// Display formatting for the web admin. Money arrives from the API as 2-decimal strings (D-09)
// and is shown without ever going through a float: "1245.5" → "₪ 1,245.50".

export function shekel(amount) {
  let value = String(amount ?? "0").trim();
  const negative = value.startsWith("-");
  if (negative) value = value.slice(1);
  const [whole = "0", fraction = ""] = value.split(".");
  const grouped = whole.replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  return `${negative ? "-" : ""}₪ ${grouped || "0"}.${fraction.padEnd(2, "0").slice(0, 2)}`;
}

/**
 * "٢٫٥٠" → "2.50". Arabic keyboards type Arabic-Indic digits (and Persian ones on some phones) and
 * the Arabic decimal separator; prices, quantities and phones are read with Western digits only.
 * One character for one character, so the caret does not jump.
 */
export const latinDigits = (text) =>
  String(text).replace(/[٠-٩۰-۹٫]/g, (c) => (c === "٫" ? "." : String(c.charCodeAt(0) & 0xf))); // ٠ U+0660, ۰ U+06F0

/** For bar heights only (never for amounts shown to people). */
export const amountNumber = (amount) => Number.parseFloat(amount ?? "0") || 0;

export const isPositiveAmount = (amount) => /[1-9]/.test(String(amount ?? "0"));

/** Arabic counting words for «N دفعة / زبون / فاتورة» style labels. */
export function arCount(n, { one, two, few, many }) {
  if (n === 1) return one;
  if (n === 2) return two;
  if (n >= 3 && n <= 10) return `${n} ${few}`;
  return `${n} ${many}`;
}

const dateParts = (date, timeZone, options) =>
  new Intl.DateTimeFormat("ar-u-nu-latn", { timeZone, ...options }).format(date);

/** dd/mm/yyyy with Western digits in the store timezone. */
export function dayMonthYear(date, timeZone) {
  const parts = new Intl.DateTimeFormat("en-GB", { timeZone, day: "2-digit", month: "2-digit", year: "numeric" }).formatToParts(date);
  const get = (type) => parts.find((p) => p.type === type)?.value ?? "";
  return `${get("day")}/${get("month")}/${get("year")}`;
}

export const weekdayName = (date, timeZone) => dateParts(date, timeZone, { weekday: "long" });
export const monthName = (date, timeZone) => dateParts(date, timeZone, { month: "long" });

/** The initial shown in an avatar: the name without «أبو» / «أم». */
export function initialOf(name = "") {
  const bare = name.replace(/^(أبو|أم)\s+/, "").trim();
  return bare ? Array.from(bare)[0] : "";
}

/** Last 6 characters of a correlation id, the support reference (US-0106). */
export const shortReference = (id) => (id ? String(id).slice(-6) : null);

const DT = new Intl.DateTimeFormat("en-GB", { day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit", hour12: false });
const D = new Intl.DateTimeFormat("en-GB", { day: "2-digit", month: "2-digit", year: "numeric" });

/** dd/mm/yyyy hh:mm in the browser timezone (the store and its browsers share Asia/Hebron). */
export const dateTime = (iso) => (iso ? DT.format(new Date(iso)).replace(",", "") : "—");
/** dd/mm/yyyy; a bare Y-m-d is read at local noon so it never shifts a day. */
export const dateOnly = (iso) => (iso ? D.format(new Date(iso.length === 10 ? `${iso}T12:00:00` : iso)) : "—");
