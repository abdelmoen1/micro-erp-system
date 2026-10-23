import { Buffer } from "node:buffer";
import { expect, test } from "@playwright/test";

// S3 back office (W-07, W-11/W-12, W-14, US-0408, W-15). The API is mocked with the response shapes
// of the Laravel resources; each test checks what the screen shows and what it sends.

const owner = { id: 1, name: "علي أحمد", email: "ali@shop.ps", role: "owner", store: { id: 1, name: "بقالة الأمانة" } };

async function signIn(page, user = owner) {
  await page.addInitScript((u) => {
    localStorage.setItem("token", "2|test-token");
    localStorage.setItem("user", JSON.stringify(u));
  }, user);
}

const customer = { id: 7, name: "أبو محمد", phone: "0599123456", credit_limit: "500.00", status: "active", debts_count: 3 };

test("W-07: statement shows a running balance and a custom payment is sent with a key", async ({ page }) => {
  await signIn(page);
  let paid = null;
  await page.route("**/api/v1/customers/7", (r) => r.fulfill({ json: { data: customer } }));
  await page.route("**/api/v1/customers/7/summary", (r) =>
    r.fulfill({ json: { data: { total_debt: "200.00", paid: "50.00", returned: "15.00", remaining: "135.00", overdue: "85.00", open_debts_count: 2 } } }),
  );
  await page.route("**/api/v1/customers/7/statement**", (r) =>
    r.fulfill({
      json: {
        data: {
          opening_balance: "0.00",
          closing_balance: "135.00",
          events: [
            { at: "2026-10-05T10:00:00Z", type: "sale", debit: "200.00", credit: "0.00", balance: "200.00", invoice_id: 12, total_amount: "200.00", paid_at_sale: "0.00", voided: false },
            { at: "2026-10-09T10:00:00Z", type: "payment", debit: "0.00", credit: "50.00", balance: "150.00", method: "cash", by: "علي أحمد" },
            { at: "2026-10-14T10:00:00Z", type: "return", debit: "0.00", credit: "15.00", balance: "135.00", invoice_id: 12, total_amount: "15.00", refund_amount: "0.00", reason: "تالف" },
          ],
        },
      },
    }),
  );
  await page.route("**/api/v1/customers/7/debts/pay-all", async (r) => {
    paid = { body: r.request().postDataJSON(), key: r.request().headers()["idempotency-key"] };
    await r.fulfill({ status: 201, json: { data: { payment_group_id: "g1", debts_count: 1, total_paid: "60.00", remaining_after: "75.00" } } });
  });

  await page.goto("/customers/7");
  await expect(page.getByRole("heading", { name: "أبو محمد" })).toBeVisible();
  const ledger = page.getByRole("table", { name: "كشف حساب أبو محمد" });
  await expect(ledger.getByRole("row")).toHaveCount(4);
  await expect(ledger.getByRole("row").nth(3)).toContainText("₪ 135.00");

  await page.getByRole("button", { name: "تسجيل دفعة" }).click();
  const dialog = page.getByRole("dialog", { name: /تسجيل دفعة من أبو محمد/ });
  await dialog.getByRole("button", { name: "مبلغ آخر" }).click();
  await dialog.getByRole("textbox", { name: "المبلغ" }).fill("200");
  await expect(dialog.getByText("المبلغ أكبر من المتبقي")).toBeVisible();
  await dialog.getByRole("textbox", { name: "المبلغ" }).fill("60");
  await expect(dialog.getByText("₪ 75.00")).toBeVisible();
  await dialog.getByRole("button", { name: "تسجيل الدفعة" }).click();
  await expect.poll(() => paid).not.toBeNull();
  expect(paid.body).toEqual({ method: "cash", amount: "60" });
  expect(paid.key).toMatch(/^[0-9a-f-]{36}$/);
});

const sale = {
  id: 12,
  source: "sale",
  status: "active",
  has_debt: true,
  total_amount: "85.00",
  paid_amount: "0.00",
  created_at: "2026-10-05T10:00:00Z",
  seller: { id: 1, name: "علي أحمد" },
  customer,
  items: [
    { id: 31, product_id: 4, item_name: "تونة 160 غ", unit: "piece", quantity: "5", returned_quantity: "2", unit_price: "7.50", line_total: "37.50" },
    { id: 32, product_id: 5, item_name: "لوز نيء", unit: "kg", quantity: "0.800", returned_quantity: "0.000", unit_price: "60.00", line_total: "48.00" },
  ],
  debt: { id: 9, amount: "85.00", return_credit: "15.00", total_payments: "0.00", remaining_amount: "70.00", status: "partially_paid", due_date: "2026-10-12" },
  returns: [{ id: 3, total_amount: "15.00", debt_reduction: "15.00", refund_amount: "0.00", reason: "منبعجة", created_by: "علي أحمد", created_at: "2026-10-14T10:00:00Z", items: [{ item_name: "تونة 160 غ", quantity: "2" }] }],
};

test("W-11/W-12: void is blocked by returns; the return preview splits debt and refund", async ({ page }) => {
  await signIn(page);
  let sent = null;
  await page.route("**/api/v1/sales/12", (r) => r.fulfill({ json: { data: sale } }));
  await page.route("**/api/v1/sales/12/returns", async (r) => {
    sent = r.request().postDataJSON();
    await r.fulfill({ status: 201, json: { data: { id: 4 }, invoice: { ...sale } } });
  });

  await page.goto("/sales/12");
  await expect(page.getByRole("button", { name: "إلغاء الفاتورة" })).toBeDisabled();
  await expect(page.getByText("لا يمكن إلغاء الفاتورة: عليها مرتجع.")).toBeVisible();

  await page.getByRole("button", { name: "مرتجع" }).click();
  const dialog = page.getByRole("dialog", { name: /مرتجع من الفاتورة/ });
  for (let i = 0; i < 4; i++) await dialog.getByRole("button", { name: "زيادة تونة 160 غ" }).click({ force: true });
  await expect(dialog.getByRole("button", { name: "زيادة تونة 160 غ" })).toBeDisabled();
  await dialog.getByLabel("الكمية المرتجعة من لوز نيء بالكغ").fill("0.900");
  await expect(dialog.getByText("الحد الأقصى 0.800")).toBeVisible();
  await dialog.getByLabel("الكمية المرتجعة من لوز نيء بالكغ").fill("0.800");
  // 3 × 7.50 + 0.800 × 60.00 = 70.50; the debt has 70.00 open → 0.50 back in cash.
  await expect(dialog.getByText("₪ 70.50")).toBeVisible();
  await expect(dialog.getByText("₪ 0.50")).toBeVisible();

  await dialog.getByRole("button", { name: "تأكيد المرتجع" }).click();
  await expect(dialog.getByText("اكتب سبب الإرجاع.")).toBeVisible();
  expect(sent).toBeNull();
  await dialog.getByLabel("سبب الإرجاع").fill("تالف");
  await dialog.getByRole("button", { name: "تأكيد المرتجع" }).click();
  await expect.poll(() => sent).not.toBeNull();
  expect(sent).toEqual({ reason: "تالف", items: [{ invoice_item_id: 31, quantity: "3" }, { invoice_item_id: 32, quantity: "0.800" }] });
});

test("W-14: a pay-all group is reversed as a whole", async ({ page }) => {
  await signIn(page);
  let path = null;
  await page.route("**/api/v1/payments?**", (r) =>
    r.fulfill({
      json: {
        data: [
          {
            type: "pay_all",
            id: 40,
            payment_group_id: "grp-1",
            total_amount: "120.00",
            method: "cash",
            paid_at: "2026-10-22T07:40:00Z",
            created_by: "علي أحمد",
            is_reversed: false,
            customer: { id: 8, name: "أم سامي" },
            applied_to: [
              { debt_id: 1, invoice_id: 18, source: "sale", amount: "70.00" },
              { debt_id: 2, invoice_id: 31, source: "sale", amount: "50.00" },
            ],
          },
        ],
        meta: { current_page: 1, last_page: 1, total: 1 },
      },
    }),
  );
  await page.route("**/api/v1/payment-groups/grp-1/reverse", async (r) => {
    path = r.request().url();
    await r.fulfill({ json: { data: { total_reversed: "120.00" } } });
  });

  await page.goto("/payments");
  await page.getByRole("button", { name: "عكس العملية كاملة" }).click();
  const dialog = page.getByRole("alertdialog");
  await expect(dialog.getByText("تُعكس كاملة معاً")).toBeVisible();
  await dialog.getByLabel("سبب العكس").fill("الزبون الخطأ");
  await dialog.getByRole("button", { name: /عكس العملية كاملة \(2 دفعات\)/ }).click();
  await expect.poll(() => path).toContain("/payment-groups/grp-1/reverse");
});

test("US-0408: a CSV with errors lists them by row and cannot be imported", async ({ page }) => {
  await signIn(page);
  await page.route("**/api/v1/products?**", (r) => r.fulfill({ json: { data: [], meta: { current_page: 1, last_page: 1, total: 0 } } }));
  await page.route("**/api/v1/products/negative-stock", (r) => r.fulfill({ json: { data: [] } }));
  await page.route("**/api/v1/products/import", (r) =>
    r.fulfill({
      status: 422,
      json: {
        message: "1 من 2 صفًا فيها أخطاء. لم يُستورد شيء.",
        code: "IMPORT_INVALID",
        errors: { file: ["x"] },
        details: { rows: 2, invalid_rows: 1, errors: [{ row: 3, column: "selling_price", message: "سعر البيع مطلوب" }] },
        correlation_id: "01ABCDEF",
      },
    }),
  );

  await page.goto("/products");
  await page.getByRole("button", { name: "استيراد من ملف CSV" }).first().click();
  const dialog = page.getByRole("dialog", { name: "استيراد المنتجات من ملف CSV" });
  await dialog.locator('input[type="file"]').setInputFiles({ name: "p.csv", mimeType: "text/csv", buffer: Buffer.from("name,selling_price,current_stock\nTea,6,1\nMilk,,2\n") });
  await expect(dialog.getByRole("cell", { name: "سعر البيع مطلوب" })).toBeVisible();
  await expect(dialog.getByRole("button", { name: "استيراد", exact: true })).toBeDisabled();
});

test("W-15: a manager is told the staff page is the owner's", async ({ page }) => {
  await signIn(page, { ...owner, role: "manager" });
  await page.route("**/api/v1/users", (r) => r.fulfill({ json: { data: [] } }));
  await page.goto("/staff");
  await expect(page.getByText("هذه الصفحة للمالك فقط")).toBeVisible();
  await expect(page.getByRole("link", { name: "الموظفون" })).toHaveCount(0);
});

test("shared catalog: a barcode another store saved fills the name and unit; mine is sent with my price and stock", async ({ page }) => {
  await signIn(page);
  let sent = null;
  await page.route("**/api/v1/products/catalog-lookup**", (r) =>
    r.fulfill({ json: { data: { barcode: "6291041500213", product: null, catalog_product: { id: 4, barcode: "6291041500213", name: "عصير برتقال 1 لتر", unit: "piece" } } } }),
  );
  await page.route("**/api/v1/products", async (r) => {
    sent = r.request().postDataJSON();
    await r.fulfill({ status: 201, json: { message: "تم إنشاء المنتج بنجاح", product: { id: 30, catalog_product_id: 4, ...sent, current_stock: "6", minimum_stock: "5", is_low_stock: false, status: "active" } } });
  });
  // After saving, the form navigates to the new product's page.
  await page.route(/\/api\/v1\/products\/30(\/movements)?$/, (r) =>
    r.fulfill({ json: { data: r.request().url().endsWith("/30") ? { id: 30, name: "عصير برتقال 1 لتر", unit: "piece", current_stock: "6", minimum_stock: "5" } : [] } }),
  );

  await page.goto("/products/new");
  await page.getByLabel("الباركود").fill("6291041500213");
  await page.getByLabel("الباركود").blur();
  await expect(page.getByText("منتج معروف في حسبة")).toBeVisible();
  await expect(page.getByLabel("اسم المنتج")).toHaveValue("عصير برتقال 1 لتر");

  await page.getByLabel("سعر البيع").fill("7.50");
  await page.getByLabel("المخزون الآن").fill("6");
  await page.getByRole("button", { name: "حفظ المنتج" }).click();
  await expect.poll(() => sent).toMatchObject({ name: "عصير برتقال 1 لتر", barcode: "6291041500213", unit: "piece", selling_price: "7.50", current_stock: "6" });
});

test("shared catalog: a barcode already in my store links to it instead of adding it twice", async ({ page }) => {
  await signIn(page);
  await page.route("**/api/v1/products/catalog-lookup**", (r) =>
    r.fulfill({ json: { data: { barcode: "6291041500213", product: { id: 9, name: "عصير برتقال", barcode: "6291041500213", unit: "piece", current_stock: "4" }, catalog_product: { id: 4, name: "عصير برتقال", unit: "piece" } } } }),
  );

  await page.goto("/products/new");
  await page.getByLabel("الباركود").fill("6291041500213");
  await page.getByLabel("الباركود").blur();
  await expect(page.getByText("هذا الباركود مسجّل في متجرك")).toBeVisible();
  await expect(page.getByRole("link", { name: "عصير برتقال" })).toHaveAttribute("href", "/products/9");
});
