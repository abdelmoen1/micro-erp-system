// Back-office domain helpers shared by the S3 screens (roles, payment methods, stock and sale kinds).

export const roleOf = (user) => user?.role ?? "employee";

/** Where a store user lands after signing in: the renewal screen once the trial / subscription has ended. */
export const landingPath = (user) => (user?.store?.has_access === false ? "/subscription-expired" : "/dashboard");
export const canManage = (user) => ["owner", "manager"].includes(roleOf(user));

// PalPay first and selected by default; cash last.
export const PAYMENT_METHODS = [
  ["palpay", "بال باي"],
  ["jawwal_pay", "جوال باي"],
  ["bank_of_palestine", "بنك فلسطين"],
  ["cash", "نقداً"],
];

export const DEFAULT_PAYMENT_METHOD = PAYMENT_METHODS[0][0];

export const methodLabel = (method) => PAYMENT_METHODS.find(([key]) => key === method)?.[1] ?? method;

/** "out" at zero, "negative" below it, "low" at or under the minimum. */
export function stockState(product) {
  const stock = Number.parseFloat(product.current_stock);
  if (stock < 0) return "negative";
  if (stock === 0) return "out";
  return product.is_low_stock ? "low" : "ok";
}

/**
 * Whole cartons on hand and the pieces of an opened one (50 pieces, 24 a carton → 2 and 2). Null
 * without a carton, for a weighed product, or below zero, where a carton count means nothing.
 */
export function cartonsOnHand(product) {
  const size = Number(product.pack_size);
  const pieces = Number(product.current_stock);
  if (product.unit !== "piece" || !size || !Number.isInteger(pieces) || pieces < 0) return null;
  return { cartons: Math.floor(pieces / size), loose: pieces % size };
}

/** "2 كرتونة + 2 قطعة", "2 كرتونة", or "—" for a product without cartons. */
export function cartonsLabel(product) {
  const c = cartonsOnHand(product);
  if (!c) return "—";
  return c.loose ? `${c.cartons} كرتونة + ${c.loose} قطعة` : `${c.cartons} كرتونة`;
}

/**
 * Pieces on hand from a carton count: cartons × pieces per carton + extra pieces. Null while a
 * field is not a valid whole number.
 */
export function cartonPieces(size, cartons, loose) {
  const whole = (v) => (/^\d{1,6}$/.test(String(v).trim()) ? Number(v) : null);
  const per = whole(size);
  const count = whole(cartons);
  const extra = String(loose).trim() === "" ? 0 : whole(loose);
  if (per === null || per < 2 || count === null || extra === null) return null;
  return count * per + extra;
}

/** cash = nothing owed at the sale, credit = nothing paid, partial = both. */
export const saleType = (sale) => (sale.has_debt ? (Number.parseFloat(sale.paid_amount) > 0 ? "partial" : "credit") : "cash");
