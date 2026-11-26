import { expect, test } from "@playwright/test";

// Safe delete, archive and void on the web: the confirmations name the record, a reason is
// required, one Idempotency-Key per dialog, nothing is offered to staff, and a refusal from the
// server is shown as it came. The API is mocked with the response shapes of the Laravel resources.

const owner = { id: 1, name: "علي أحمد", phone: "0599333444", role: "owner", store: { id: 1, name: "الشريف ماركت", phone: "0599123456", address: "غزة" } };
const employee = { ...owner, id: 2, role: "employee" };
const pageMeta = { current_page: 1, last_page: 1, total: 1 };

async function signIn(page, user = owner) {
  await page.addInitScript((u) => {
    localStorage.setItem("token", "2|test-token");
    localStorage.setItem("user", JSON.stringify(u));
  }, user);
  await page.route("**/api/v1/sync/conflicts**", (r) => r.fulfill({ json: { data: [], meta: pageMeta, open_count: 0 } }));
}

const saleReturn = (patch = {}) => ({
  id: 5,
  invoice_id: 40,
  customer: { id: 3, name: "أبو خالد" },
  total_amount: "30.00",
  debt_reduction: "30.00",
  refund_amount: "0.00",
  reason: "تالف",
  created_by: "علي أحمد",
  created_at: "2026-11-26T09:00:00Z",
  status: "active",
  voided_at: null,
  void_reason: null,
  items: [{ invoice_item_id: 9, product_id: 3, item_name: "زيت زيتون", unit: "piece", quantity: "2", unit_price: "15.00", total: "30.00", damaged: false }],
  ...patch,
});

test("an owner cancels a customer return: the effect is shown, a reason is required, one key is sent", async ({ page }) => {
  await signIn(page);
  let voided = false;
  const sent = [];
  await page.route("**/api/v1/returns/sales?**", (r) =>
    r.fulfill({ json: { data: [voided ? saleReturn({ status: "voided", voided_at: "2026-11-26T10:00:00Z", voided_by_name: "علي أحمد", void_reason: "سُجّل بالخطأ" }) : saleReturn()], meta: pageMeta } }),
  );
  await page.route("**/api/v1/returns/sales/5/void", async (r) => {
    sent.push({ body: r.request().postDataJSON(), key: r.request().headers()["idempotency-key"] });
    await new Promise((resolve) => setTimeout(resolve, 300));
    voided = true;
    await r.fulfill({ json: { message: "تم إلغاء المرتجع وإعادة الدين والمخزون كما كانا.", data: saleReturn({ status: "voided" }) } });
  });

  await page.goto("/returns");
  await page.getByRole("button", { name: "إلغاء المرتجع على الفاتورة #40" }).click();
  const dialog = page.getByRole("alertdialog", { name: "إلغاء المرتجع على الفاتورة #40؟" });
  await expect(dialog.getByText("2 × زيت زيتون")).toBeVisible();
  await expect(dialog.getByText("يعود على دين أبو خالد")).toBeVisible();

  await dialog.getByRole("button", { name: "إلغاء المرتجع" }).click();
  await expect(dialog.getByText("يجب كتابة سبب الإلغاء.")).toBeVisible();
  expect(sent).toHaveLength(0);

  await dialog.getByRole("textbox", { name: "سبب الإلغاء" }).fill("سُجّل بالخطأ");
  await dialog.getByRole("button", { name: "إلغاء المرتجع" }).click();
  // The button is locked while the request runs, so a double click sends nothing more.
  await expect(dialog.getByRole("button", { name: "جارٍ الإلغاء…" })).toBeDisabled();
  await expect(dialog).toHaveCount(0);

  expect(sent).toHaveLength(1);
  expect(sent[0].body).toEqual({ reason: "سُجّل بالخطأ" });
  expect(sent[0].key).toBeTruthy();
  // The register refreshes: the return stays, marked cancelled, with no cancel button.
  await expect(page.getByText("سُجّل بالخطأ")).toBeVisible();
  await expect(page.getByRole("button", { name: "إلغاء المرتجع على الفاتورة #40" })).toHaveCount(0);
});

test("a refused cancel shows the server's reason and changes nothing on screen", async ({ page }) => {
  await signIn(page);
  await page.route("**/api/v1/returns/sales?**", (r) => r.fulfill({ json: { data: [saleReturn()], meta: pageMeta } }));
  await page.route("**/api/v1/returns/sales/5/void", (r) =>
    r.fulfill({
      status: 409,
      json: { code: "RETURN_STOCK_CONSUMED", message: "لا يمكن إلغاء المرتجع: الكمية المرتجعة من «زيت زيتون» لم تعد في المخزون (المتوفر الآن 0). صحّح المخزون أولًا ثم أعد المحاولة." },
    }),
  );

  await page.goto("/returns");
  await page.getByRole("button", { name: "إلغاء المرتجع على الفاتورة #40" }).click();
  const dialog = page.getByRole("alertdialog");
  await dialog.getByRole("textbox", { name: "سبب الإلغاء" }).fill("خطأ");
  await dialog.getByRole("button", { name: "إلغاء المرتجع" }).click();
  await expect(dialog.getByRole("alert")).toContainText("لم تعد في المخزون");
  await expect(dialog.getByRole("button", { name: "إلغاء المرتجع" })).toBeEnabled();
});

test("an employee is offered no cancel, delete or take-back", async ({ page }) => {
  await signIn(page, employee);
  await page.route("**/api/v1/returns/sales?**", (r) => r.fulfill({ json: { data: [saleReturn()], meta: pageMeta } }));
  await page.route("**/api/v1/products/3", (r) =>
    r.fulfill({ json: { data: { id: 3, name: "زيت زيتون", unit: "piece", selling_price: "15.00", current_stock: "8", minimum_stock: "2", status: "active" } } }),
  );
  await page.route("**/api/v1/products/3/movements**", (r) =>
    r.fulfill({ json: { data: [{ id: 70, type: "adjustment_in", quantity: "3", balance_after: "8", reason: "جرد", created_at: "2026-11-26T08:00:00Z" }], meta: pageMeta } }),
  );

  await page.goto("/returns");
  await expect(page.getByText("2 × زيت زيتون")).toBeVisible();
  await expect(page.getByRole("button", { name: /إلغاء المرتجع/ })).toHaveCount(0);

  await page.goto("/products/3");
  await expect(page.getByText("تعديل: زيادة")).toBeVisible();
  await expect(page.getByRole("button", { name: /تراجع/ })).toHaveCount(0);
  await expect(page.getByRole("button", { name: /حذف الصنف/ })).toHaveCount(0);
});

test("a product nothing refers to can be deleted; one with history can only be stopped", async ({ page }) => {
  await signIn(page);
  let deleted = null;
  const product = (id, deletable) => ({ id, name: id === 4 ? "صنف بالخطأ" : "زيت زيتون", unit: "piece", selling_price: "15.00", current_stock: "0", minimum_stock: "0", status: "active", deletable });
  await page.route("**/api/v1/products/4", async (r) => {
    if (r.request().method() === "DELETE") {
      deleted = r.request().url();
      return r.fulfill({ json: { message: "تم حذف المنتج نهائيًا." } });
    }
    return r.fulfill({ json: { data: product(4, true) } });
  });
  await page.route("**/api/v1/products/3", (r) => r.fulfill({ json: { data: product(3, false) } }));
  await page.route("**/api/v1/products/*/movements**", (r) => r.fulfill({ json: { data: [], meta: pageMeta } }));
  await page.route("**/api/v1/products?**", (r) => r.fulfill({ json: { data: [], meta: { ...pageMeta, total: 0 } } }));
  await page.route("**/api/v1/products/low-stock", (r) => r.fulfill({ json: { data: [] } }));

  await page.goto("/products/3");
  await expect(page.getByRole("button", { name: "إيقاف الصنف" })).toBeVisible();
  await expect(page.getByRole("button", { name: "حذف الصنف نهائياً" })).toHaveCount(0);

  await page.goto("/products/4");
  await page.getByRole("button", { name: "حذف الصنف نهائياً" }).click();
  const dialog = page.getByRole("alertdialog", { name: "حذف «صنف بالخطأ» نهائياً؟" });
  await dialog.getByRole("button", { name: "حذف الصنف نهائياً" }).click();
  await expect(page).toHaveURL(/\/products$/);
  expect(deleted).toContain("/api/v1/products/4");
});

test("a line comes off a held invoice with its name and the new total in the confirmation", async ({ page }) => {
  await signIn(page);
  let removed = null;
  const held = {
    id: 8,
    reference: "H-20261126-0001",
    status: "pending_transfer",
    cashier_id: 1,
    cashier: { id: 1, name: "علي أحمد" },
    total_amount: "40.00",
    account_snapshot_name: "الحساب",
    account_snapshot_identifier: "0590000000",
    created_at: "2026-11-26T09:00:00Z",
    items: [
      { id: 81, item_name: "شاي", quantity: "3.000", total: "30.00" },
      { id: 82, item_name: "سكر", quantity: "2.000", total: "10.00" },
    ],
  };
  await page.route("**/api/v1/suspended-invoices?**", (r) => r.fulfill({ json: { data: [held] } }));
  await page.route("**/api/v1/suspended-invoices/8/items/82", (r) => {
    removed = r.request().method();
    return r.fulfill({ json: { data: { ...held, total_amount: "30.00", items: [held.items[0]] } } });
  });

  await page.goto("/suspended-invoices");
  await page.getByRole("button", { name: "حذف سكر من الفاتورة #H-20261126-0001" }).click();
  const dialog = page.getByRole("alertdialog", { name: "حذف «سكر» من الفاتورة #H-20261126-0001؟" });
  await expect(dialog.getByText("₪ 30.00")).toBeVisible();
  await dialog.getByRole("button", { name: "حذف البند" }).click();
  await expect(dialog).toHaveCount(0);
  expect(removed).toBe("DELETE");
});

test("a supplier invoice with a live return cannot be voided until the return is cancelled", async ({ page }) => {
  await signIn(page);
  const purchase = {
    id: 12,
    supplier: { id: 7, name: "التاج مول" },
    total: "240.00",
    paid_amount: "0.00",
    returned_amount: "60.00",
    lines_count: 1,
    by: "علي أحمد",
    at: "2026-11-01T08:00:00Z",
    status: "active",
    items: [{ id: 21, product_id: 3, item_name: "كولا علبة", unit: "piece", quantity: "96", returned_quantity: "24", remaining_quantity: "72", cartons: 4, pack_size: 24, buy_price: "60.00", line_total: "240.00", remaining_line_value: "180.00" }],
    returns: [{ id: 3, purchase_invoice_id: 12, total_amount: "60.00", balance_reduction: "60.00", refund_amount: "0.00", reason: "تالف", created_at: "2026-11-02T08:00:00Z", status: "active", items: [{ purchase_item_id: 21, item_name: "كولا علبة", quantity: "24", total: "60.00", from_stock: true }] }],
  };
  await page.route("**/api/v1/purchases/12", (r) => r.fulfill({ json: { data: purchase } }));
  await page.route("**/api/v1/suppliers/7", (r) => r.fulfill({ json: { data: { id: 7, name: "التاج مول", balance: "180.00", products: [], payments: [], returns: [] } } }));

  await page.goto("/purchases/12");
  await expect(page.getByRole("button", { name: "إلغاء الفاتورة" })).toBeDisabled();
  await expect(page.getByText("ألغِ المرتجعات أولاً ثم ألغِ الفاتورة.")).toBeVisible();

  await page.getByRole("button", { name: "إلغاء المرتجع" }).click();
  const dialog = page.getByRole("alertdialog", { name: "إلغاء المرتجع على الفاتورة #12؟" });
  await expect(dialog.getByText("يعود لرصيد التاج مول")).toBeVisible();
  await expect(dialog.getByText("24 × كولا علبة")).toBeVisible();
});

test("the cancel dialog fits a phone screen in RTL", async ({ page }) => {
  await page.setViewportSize({ width: 375, height: 760 });
  await signIn(page);
  await page.route("**/api/v1/returns/sales?**", (r) => r.fulfill({ json: { data: [saleReturn()], meta: pageMeta } }));

  await page.goto("/returns");
  await page.getByRole("button", { name: "إلغاء المرتجع على الفاتورة #40" }).click();
  const dialog = page.getByRole("alertdialog");
  await expect(dialog).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.dir)).toBe("rtl");
  const box = await dialog.boundingBox();
  expect(box.x).toBeGreaterThanOrEqual(0);
  expect(box.x + box.width).toBeLessThanOrEqual(375);
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(375);
});
