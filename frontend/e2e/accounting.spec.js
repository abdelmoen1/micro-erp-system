import { expect, test } from "@playwright/test";

// Purchases, suppliers, both kinds of returns, printing, and a dashboard whose figures open what
// they count. The API is mocked with the response shapes of the Laravel resources.

const owner = { id: 1, name: "علي أحمد", phone: "0599333444", role: "owner", store: { id: 1, name: "الشريف ماركت", phone: "0599123456", address: "غزة" } };
const employee = { ...owner, role: "employee" };
const pageMeta = { current_page: 1, last_page: 1, total: 1 };

async function signIn(page, user = owner) {
  await page.addInitScript((u) => {
    localStorage.setItem("token", "2|test-token");
    localStorage.setItem("user", JSON.stringify(u));
  }, user);
  await page.route("**/api/v1/sync/conflicts**", (r) => r.fulfill({ json: { data: [], meta: pageMeta, open_count: 0 } }));
}

const dashboard = (purchases = { total: "240.00", count: 1, returns_total: "0.00", returns_count: 0, owed_to_suppliers: "318.00" }) => ({
  data: {
    period: { key: "today", from: "2026-10-31T22:00:00Z", to: "2026-11-01T21:59:59Z", timezone: "Asia/Gaza" },
    summary: { total_sales: "156.00", net_sales: "152.00", cash_sales: "114.00", credit_sales: "42.00", collected_at_sale: "114.00", new_debt: "42.00", total_remaining_debt: "22.00", invoices_count: 10 },
    payments: { total_collected: "20.00", count: 1 },
    customers: { with_outstanding_debts: 2 },
    returns: { count: 1, total: "4.00", debt_reduction: "0.00", refunded: "4.00" },
    purchases,
    charts: { sales: [], sales_hourly: [] },
    recent_invoices: [{ id: 40, customer: null, total_amount: "30.00", type: "cash" }],
  },
});

const purchase = {
  id: 12,
  supplier: { id: 7, name: "التاج مول" },
  total: "240.00",
  returned_amount: "0.00",
  lines_count: 1,
  by: "علي أحمد",
  at: "2026-11-01T08:00:00Z",
  items: [{ id: 21, product_id: 3, item_name: "كولا علبة", unit: "piece", quantity: "96", returned_quantity: "0", cartons: 4, pack_size: 24, buy_price: "60.00", line_total: "240.00" }],
  returns: [],
};

const sale = {
  id: 40,
  source: "sale",
  status: "active",
  total_amount: "30.00",
  paid_amount: "30.00",
  debt_amount: "0.00",
  payment_method: "cash",
  created_at: "2026-11-01T09:00:00Z",
  seller: { id: 1, name: "علي أحمد" },
  items: [{ id: 9, product_id: 3, item_name: "زيت زيتون", unit: "piece", quantity: "2", base_quantity: "2", returned_quantity: "0", unit_price: "15.00", line_total: "30.00" }],
  returns: [],
  returned_amount: "0.00",
};

async function dashboardRoutes(page, body = dashboard()) {
  await page.route("**/api/v1/dashboard**", (r) => r.fulfill({ json: body }));
  await page.route("**/api/v1/products/low-stock", (r) => r.fulfill({ json: { data: [] } }));
  await page.route("**/api/v1/products?status=all", (r) => r.fulfill({ json: { data: [], meta: { total: 3 } } }));
}

test("the dashboard's figures open the list behind them, filtered to the period", async ({ page }) => {
  await signIn(page);
  await dashboardRoutes(page);
  const asked = [];
  await page.route("**/api/v1/sales?**", (r) => {
    asked.push(new URL(r.request().url()).searchParams);
    return r.fulfill({ json: { data: [sale], meta: pageMeta } });
  });

  await page.goto("/dashboard");
  await page.getByRole("button", { name: "لاحقاً" }).click();
  await page.getByRole("link", { name: "آجل (دين): افتح التفاصيل" }).click();
  await expect(page).toHaveURL(/\/sales\?from=2026-11-01&to=2026-11-01&type=on_credit/);
  await expect(page.getByRole("heading", { name: "المبيعات", exact: true })).toBeVisible();
  await expect.poll(() => asked.at(-1)?.get("type")).toBe("on_credit");
  expect(asked.at(-1).get("from")).toBe("2026-11-01");

  await page.goto("/dashboard");
  await expect(page.getByRole("link", { name: "المشتريات: افتح التفاصيل" })).toHaveAttribute("href", /\/purchases\?from=2026-11-01/);
  await expect(page.getByRole("link", { name: "الديون المستحقة: افتح التفاصيل" })).toHaveAttribute("href", "/debts?bucket=balance");
  await expect(page.getByRole("link", { name: "المرتجعات: افتح التفاصيل" })).toContainText("₪ 152.00");
});

test("the menu says المخزن, with purchases and suppliers beside it; an employee sees neither", async ({ page }) => {
  await signIn(page, employee);
  await dashboardRoutes(page, dashboard(null));
  await page.goto("/dashboard");
  const nav = page.getByRole("navigation", { name: "القائمة الرئيسية" });
  await expect(nav.getByRole("link", { name: "المخزن" })).toBeVisible();
  await expect(nav.getByRole("link", { name: "البضاعة" })).toHaveCount(0);
  await expect(nav.getByRole("link", { name: "المرتجعات" })).toBeVisible();
  await expect(nav.getByRole("link", { name: "المشتريات" })).toHaveCount(0);
  await expect(nav.getByRole("link", { name: "الموردين" })).toHaveCount(0);
  await expect(page.getByRole("link", { name: "المشتريات: افتح التفاصيل" })).toHaveCount(0);
});

test("a return to the supplier previews the split and sends what the page shows", async ({ page }) => {
  await signIn(page);
  let sent = null;
  await page.route("**/api/v1/purchases/12", (r) => r.fulfill({ json: { data: purchase } }));
  await page.route("**/api/v1/suppliers/7", (r) => r.fulfill({ json: { data: { id: 7, name: "التاج مول", balance: "10.00", products: [], payments: [], returns: [] } } }));
  await page.route("**/api/v1/purchases/12/returns", async (r) => {
    sent = { body: r.request().postDataJSON(), key: r.request().headers()["idempotency-key"] };
    await r.fulfill({ status: 201, json: { data: { id: 3 }, balance: "0.00" } });
  });

  await page.goto("/purchases/12");
  await page.getByRole("button", { name: "إرجاع للمورد" }).click();
  const dialog = page.getByRole("dialog", { name: "إرجاع من الفاتورة #12" });
  await dialog.getByRole("textbox", { name: "الكمية المرتجعة من كولا علبة" }).fill("97");
  await expect(dialog.getByText("الحد الأقصى 96")).toBeVisible();
  await dialog.getByRole("textbox", { name: "الكمية المرتجعة من كولا علبة" }).fill("24");
  await expect(dialog.getByText("₪ 60.00")).toBeVisible();
  await expect(dialog.getByText("₪ 50.00")).toBeVisible();
  await dialog.getByRole("checkbox", { name: "كولا علبة خارج المخزن" }).check();
  await dialog.getByRole("textbox", { name: "سبب الإرجاع" }).fill("خلاف على البضاعة");
  await dialog.getByRole("button", { name: "سجّل المرتجع" }).click();

  await expect(dialog).toHaveCount(0);
  expect(sent.body).toEqual({ items: [{ purchase_item_id: 21, quantity: "24", from_stock: false }], reason: "خلاف على البضاعة" });
  expect(sent.key).toBeTruthy();
});

test("a customer return can mark a line damaged", async ({ page }) => {
  await signIn(page);
  let sent = null;
  await page.route("**/api/v1/sales/40", (r) => r.fulfill({ json: { data: sale } }));
  await page.route("**/api/v1/sales/40/returns", async (r) => {
    sent = r.request().postDataJSON();
    await r.fulfill({ status: 201, json: { data: { id: 5 }, invoice: sale } });
  });

  await page.goto("/sales/40");
  await page.getByRole("button", { name: "مرتجع" }).click();
  const dialog = page.getByRole("dialog");
  await dialog.getByRole("button", { name: "زيادة زيت زيتون" }).click();
  await dialog.getByRole("checkbox", { name: "زيت زيتون تالفة" }).check();
  await dialog.getByRole("textbox", { name: "سبب الإرجاع" }).fill("علبة مفتوحة");
  await dialog.getByRole("button", { name: "تأكيد المرتجع" }).click();

  await expect(dialog).toHaveCount(0);
  expect(sent.items).toEqual([{ invoice_item_id: 9, quantity: "1", damaged: true }]);
});

test("printing puts the invoice alone on the paper", async ({ page }) => {
  await signIn(page);
  await page.route("**/api/v1/sales/40", (r) => r.fulfill({ json: { data: sale } }));
  await page.addInitScript(() => {
    window.print = () => {
      window.printed = (window.printed ?? 0) + 1;
    };
  });

  await page.goto("/sales/40");
  await expect(page.locator(".print-doc")).toHaveCount(0);
  await page.getByRole("button", { name: "طباعة" }).click();
  await expect.poll(() => page.evaluate(() => window.printed)).toBe(1);

  const paper = page.locator(".print-doc");
  await expect(paper).toBeHidden();
  await page.emulateMedia({ media: "print" });
  await expect(paper).toBeVisible();
  await expect(paper).toContainText("الشريف ماركت");
  await expect(paper).toContainText("فاتورة مبيعات");
  await expect(paper).toContainText("زيت زيتون");
  await expect(paper).toContainText("₪ 30.00");
  await expect(paper.locator("thead th")).toHaveText(["الصنف", "الكمية", "السعر", "المبلغ"]);
  await expect(paper.locator("tbody tr").first().locator("td")).toHaveText(["زيت زيتون", "2", "15.00", "30.00"]);
  await expect(page.locator("#root")).toBeHidden();
});

test("a discount at the till shows on the sale and on its paper", async ({ page }) => {
  await signIn(page);
  const discounted = { ...sale, total_amount: "29.00", paid_amount: "29.00", discount_amount: "1.00", subtotal_amount: "30.00" };
  await page.route("**/api/v1/sales/40", (r) => r.fulfill({ json: { data: discounted } }));
  await page.addInitScript(() => {
    window.print = () => {};
  });

  await page.goto("/sales/40");
  await expect(page.locator("tfoot")).toContainText("الخصم");
  await expect(page.locator("tfoot")).toContainText("₪ 1.00");

  await page.getByRole("button", { name: "طباعة" }).click();
  await page.emulateMedia({ media: "print" });
  const totals = page.locator(".print-totals");
  await expect(totals.locator("dt")).toHaveText(["المجموع", "الخصم", "الإجمالي", "المدفوع · نقداً"]);
  await expect(totals.locator(".strong dd")).toHaveText("₪ 29.00");
});

test("a supplier page: what is owed, a payment with a key, and the way to their invoices", async ({ page }) => {
  await signIn(page);
  let sent = null;
  await page.route("**/api/v1/suppliers/7", (r) =>
    r.fulfill({
      json: {
        data: {
          id: 7,
          name: "التاج مول",
          balance: "318.00",
          products: [{ id: 3, name: "كولا علبة", unit: "piece", total: "240.00" }],
          payments: [{ id: 1, at: "2026-11-01T09:00:00Z", amount: "100.00", method: "cash" }],
          returns: [],
        },
      },
    }),
  );
  await page.route("**/api/v1/suppliers/7/payments", async (r) => {
    sent = { body: r.request().postDataJSON(), key: r.request().headers()["idempotency-key"] };
    await r.fulfill({ status: 201, json: { data: { balance: "218.00" } } });
  });

  await page.goto("/suppliers/7");
  await expect(page.getByRole("link", { name: "فواتير المورد" })).toHaveAttribute("href", "/purchases?supplier_id=7");
  await page.getByRole("button", { name: "سجّل دفعة" }).click();
  const dialog = page.getByRole("dialog");
  await dialog.getByRole("textbox", { name: "المبلغ" }).fill("400");
  await dialog.getByRole("button", { name: "سجّل الدفعة" }).click();
  await expect(dialog.getByText("الدفعة أكبر من المبلغ المتبقي.")).toBeVisible();
  await dialog.getByRole("textbox", { name: "المبلغ" }).fill("100");
  await dialog.getByRole("button", { name: "سجّل الدفعة" }).click();
  await expect(dialog).toHaveCount(0);
  expect(sent.body.amount).toBe("100");
  expect(sent.key).toBeTruthy();
});
