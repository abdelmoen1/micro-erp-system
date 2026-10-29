import { expect, test } from "@playwright/test";

// SCR-W-18 / US-1106 (TC-1106-01): the owner reviews what the phones sent offline. A flagged sale is
// acknowledged; a held payment is applied, refunded or voided with a reason; every resolution is
// sent with an Idempotency-Key. Employees never see the page.

const owner = { id: 1, name: "علي أحمد", email: "ali@shop.ps", role: "owner", store: { id: 1, name: "بقالة الأمانة" } };
const employee = { ...owner, id: 3, name: "سامر", role: "employee" };

const flagged = {
  id: 11,
  client_transaction_id: "6f1c0f0e-1111-4aaa-8bbb-000000000001",
  type: "sale",
  kind: "flagged",
  reason: "NEGATIVE_STOCK",
  message: null,
  flags: ["NEGATIVE_STOCK", "PRICE_CHANGED"],
  amount: "26.00",
  payment_method: "cash",
  items_count: 2,
  occurred_at: "2026-10-28T19:30:00Z",
  invoice_id: 9004,
  status: "open",
  user: { id: 3, name: "سامر" },
  customer: null,
};

const held = {
  id: 12,
  client_transaction_id: "6f1c0f0e-1111-4aaa-8bbb-000000000002",
  type: "payment",
  kind: "conflict",
  reason: "PAYMENT_EXCEEDS_REMAINING",
  message: "مبلغ الدفعة أكبر من المبلغ المتبقي: 20.00",
  flags: [],
  amount: "25.00",
  payment_method: "jawwal_pay",
  items_count: null,
  occurred_at: "2026-10-28T20:00:00Z",
  invoice_id: null,
  status: "open",
  user: { id: 3, name: "سامر" },
  customer: { id: 7, name: "أبو محمد", phone: "0599123456" },
};

async function signIn(page, user) {
  await page.addInitScript((u) => {
    localStorage.setItem("token", "2|test-token");
    localStorage.setItem("user", JSON.stringify(u));
  }, user);
}

test("TC-1106-01: a flagged sale is acknowledged and a held payment needs a reason to be voided", async ({ page }) => {
  await signIn(page, owner);
  const resolved = [];
  await page.route("**/api/v1/sync/conflicts?**", (r) =>
    r.fulfill({ json: { data: [flagged, held], meta: { current_page: 1, last_page: 1 }, open_count: 2 } }),
  );
  await page.route("**/api/v1/sync/conflicts/*/resolve", async (r) => {
    resolved.push({ url: r.request().url(), body: r.request().postDataJSON(), key: r.request().headers()["idempotency-key"] });
    await r.fulfill({ json: { message: "تمت معالجة البند.", data: { ...held, status: "resolved" } } });
  });

  await page.goto("/sync");
  await expect(page.getByRole("heading", { name: "مراجعة المزامنة" })).toBeVisible();
  await expect(page.getByRole("navigation", { name: "القائمة الرئيسية" }).getByLabel("2 بانتظار المراجعة")).toBeVisible();

  const table = page.getByRole("table", { name: "عمليات المزامنة للمراجعة" });
  const sale = table.getByRole("row").filter({ hasText: "بيع · 2 أصناف" });
  await expect(sale).toContainText("بيع أكثر من المخزون المسجّل.");
  await expect(sale).toContainText("تغيّر السعر بعد آخر تحديث للهاتف");
  await expect(sale.getByRole("link", { name: "فتح الفاتورة #9004" })).toHaveAttribute("href", "/sales/9004");
  await sale.getByRole("button", { name: "تم الاطلاع" }).click();
  await expect.poll(() => resolved.length).toBe(1);
  expect(resolved[0].url).toContain("/sync/conflicts/11/resolve");
  expect(resolved[0].body).toEqual({ resolution: "acknowledged" });
  expect(resolved[0].key).toMatch(/^[0-9a-f-]{36}$/);

  const payment = table.getByRole("row").filter({ hasText: "أبو محمد" });
  await expect(payment).toContainText("دفعة · جوال باي");
  await expect(payment).toContainText("الدفعة أكبر مما على الزبون الآن");
  await payment.getByRole("button", { name: "معالجة الدفعة" }).click();

  const dialog = page.getByRole("alertdialog", { name: "دفعة موقوفة من أبو محمد" });
  await expect(dialog.getByRole("radio", { name: /تسجيلها على ديون الزبون/ })).toBeChecked();
  await dialog.getByRole("radio", { name: /إلغاؤها/ }).check();
  await dialog.getByRole("button", { name: "إلغاؤها" }).click();
  await expect(dialog.getByText("اكتب سبب الإلغاء. يظهر في سجل التدقيق.")).toBeVisible();
  expect(resolved).toHaveLength(1);

  await dialog.getByRole("textbox", { name: "سبب الإلغاء" }).fill("سُجّلت على الزبون الخطأ");
  await dialog.getByRole("button", { name: "إلغاؤها" }).click();
  await expect.poll(() => resolved.length).toBe(2);
  expect(resolved[1].url).toContain("/sync/conflicts/12/resolve");
  expect(resolved[1].body).toEqual({ resolution: "voided", note: "سُجّلت على الزبون الخطأ" });
  expect(resolved[1].key).not.toBe(resolved[0].key);
  await expect(dialog).toBeHidden();
});

test("an employee has no sync review entry and is told who reviews", async ({ page }) => {
  await signIn(page, employee);
  let asked = false;
  await page.route("**/api/v1/sync/conflicts**", (r) => {
    asked = true;
    return r.fulfill({ status: 403, json: { code: "FORBIDDEN", message: "غير مسموح" } });
  });

  await page.goto("/sync");
  await expect(page.getByText("هذه الصفحة للمالك أو المدير")).toBeVisible();
  await expect(page.getByRole("navigation", { name: "القائمة الرئيسية" }).getByRole("link", { name: "مراجعة المزامنة" })).toHaveCount(0);
  expect(asked).toBe(false);
});
