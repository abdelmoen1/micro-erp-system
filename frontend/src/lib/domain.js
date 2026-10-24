// Back-office domain helpers shared by the S3 screens (roles, payment methods, stock and sale kinds).

export const roleOf = (user) => user?.role ?? "employee";

/** Where a store user lands after signing in: the renewal screen once the trial / subscription has ended. */
export const landingPath = (user) => (user?.store?.has_access === false ? "/subscription-expired" : "/dashboard");
export const canManage = (user) => ["owner", "manager"].includes(roleOf(user));

export const PAYMENT_METHODS = [
  ["cash", "نقداً"],
  ["jawwal_pay", "جوال باي"],
  ["palpay", "بال باي"],
  ["bank_of_palestine", "بنك فلسطين"],
];

export const methodLabel = (method) => PAYMENT_METHODS.find(([key]) => key === method)?.[1] ?? method;

/** "out" at zero, "negative" below it, "low" at or under the minimum. */
export function stockState(product) {
  const stock = Number.parseFloat(product.current_stock);
  if (stock < 0) return "negative";
  if (stock === 0) return "out";
  return product.is_low_stock ? "low" : "ok";
}

/** cash = nothing owed at the sale, credit = nothing paid, partial = both. */
export const saleType = (sale) => (sale.has_debt ? (Number.parseFloat(sale.paid_amount) > 0 ? "partial" : "credit") : "cash");
