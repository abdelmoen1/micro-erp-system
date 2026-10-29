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
  // Settings lists the store's complaints; a test that needs them routes its own.
  await page.route("**/api/v1/support-tickets", (r) => r.fulfill({ json: { data: [] } }));
  // The sidebar badge of the sync review (owner / manager).
  await page.route("**/api/v1/sync/conflicts**", (r) => r.fulfill({ json: { data: [], meta: { current_page: 1, last_page: 1 }, open_count: 0 } }));
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
  expect(paid.body).toEqual({ method: "palpay", amount: "60" }); // PalPay is the default method
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
  const dialog = page.getByRole("dialog", { name: "استيراد البضاعة من ملف CSV" });
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
    await r.fulfill({ status: 201, json: { message: "تم إنشاء الصنف بنجاح", product: { id: 30, catalog_product_id: 4, ...sent, current_stock: "6", minimum_stock: "5", is_low_stock: false, status: "active" } } });
  });
  // After saving, the form navigates to the new product's page.
  await page.route(/\/api\/v1\/products\/30(\/movements)?$/, (r) =>
    r.fulfill({ json: { data: r.request().url().endsWith("/30") ? { id: 30, name: "عصير برتقال 1 لتر", unit: "piece", current_stock: "6", minimum_stock: "5" } : [] } }),
  );

  await page.goto("/products/new");
  await page.getByLabel("الباركود").fill("6291041500213");
  await page.getByLabel("الباركود").blur();
  await expect(page.getByText("صنف معروف في حسبة")).toBeVisible();
  await expect(page.getByLabel("اسم الصنف")).toHaveValue("عصير برتقال 1 لتر");

  await page.getByRole("button", { name: "بالقطعة" }).click();
  await page.getByLabel("سعر البيع").fill("7.50");
  await page.getByLabel("الكمية الموجودة الآن").fill("6");
  await page.getByRole("button", { name: "حفظ الصنف" }).click();
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

test("cartons: a new product is counted in cartons; the pieces are worked out and sent with the carton size and price", async ({ page }) => {
  await signIn(page);
  let sent = null;
  await page.route("**/api/v1/products", async (r) => {
    sent = r.request().postDataJSON();
    await r.fulfill({ status: 201, json: { message: "تم إنشاء الصنف بنجاح", product: { id: 31, ...sent, current_stock: "48", minimum_stock: "5", is_low_stock: false, status: "active" } } });
  });
  await page.route(/\/api\/v1\/products\/31(\/movements)?$/, (r) =>
    r.fulfill({ json: { data: r.request().url().endsWith("/31") ? { id: 31, name: "ماء 600 مل", unit: "piece", current_stock: "48", minimum_stock: "5", pack_size: 24, pack_price: "54.00" } : [] } }),
  );

  await page.goto("/products/new");
  await expect(page.getByRole("button", { name: "بالكرتونة" })).toHaveAttribute("aria-pressed", "true");
  await expect(page.getByLabel("الكمية الموجودة الآن")).toHaveCount(0);
  await page.getByLabel("اسم الصنف").fill("ماء 600 مل");
  await page.getByLabel("سعر القطعة الواحدة").fill("2.50");
  await page.getByLabel("عدد الكراتين عندك").fill("2");
  await page.getByLabel("عدد القطع في الكرتونة").fill("24");
  await page.getByLabel("قطع زيادة").fill("30");
  await page.getByLabel("سعر الكرتونة (جملة)").fill("54");
  await expect(page.getByText("القطعة داخل الكرتونة بـ 2.25 ₪ مقابل 2.50 ₪ بالمفرد.")).toBeVisible();

  // Extra pieces of a full carton or more are refused before sending.
  await page.getByRole("button", { name: "حفظ الصنف" }).click();
  await expect(page.getByLabel("قطع زيادة")).toHaveAccessibleDescription("القطع الزيادة أقل من 24؛ وإلا فهي كرتونة كاملة.");
  expect(sent).toBeNull();
  await page.getByLabel("قطع زيادة").fill("3");
  await expect(page.getByRole("status").filter({ hasText: "المجموع" })).toHaveText("المجموع: 51 قطعة");

  // A weighed product has no carton: the fields go away and nothing about cartons is sent.
  await page.getByRole("button", { name: "بالوزن (كغ)" }).click();
  await expect(page.getByLabel("عدد القطع في الكرتونة")).toHaveCount(0);
  await page.getByRole("button", { name: "بالكرتونة" }).click();

  await page.getByRole("button", { name: "حفظ الصنف" }).click();
  await expect.poll(() => sent).toMatchObject({ unit: "piece", selling_price: "2.50", pack_size: "24", pack_price: "54", current_stock: "51" });
});

test("products table: name, cartons with an opened one, all pieces and the piece price", async ({ page }) => {
  await signIn(page);
  const product = (id, name, extra) => ({ id, name, barcode: null, unit: "piece", selling_price: "2.50", minimum_stock: "5", is_low_stock: false, status: "active", ...extra });
  await page.route("**/api/v1/products/negative-stock", (r) => r.fulfill({ json: { data: [] } }));
  await page.route("**/api/v1/products?**", (r) =>
    r.fulfill({
      json: {
        data: [
          product(1, "ماء 600 مل", { current_stock: "50", pack_size: 24, pack_price: "54.00" }),
          product(2, "عصير", { current_stock: "48", pack_size: 24, pack_price: "90.00", selling_price: "4.00" }),
          product(3, "لوز نيء", { unit: "kg", current_stock: "5.200", selling_price: "60.00" }),
          product(4, "شاي", { current_stock: "2", is_low_stock: true }),
        ],
        meta: { current_page: 1, last_page: 1, total: 4 },
      },
    }),
  );

  await page.goto("/products");
  const table = page.getByRole("table");
  await expect(table.getByRole("columnheader")).toHaveText(["المنتج", "عدد الكراتين", "عدد القطع الكلي", "سعر القطعة"]);
  const row = (name) => table.getByRole("row").filter({ hasText: name });
  await expect(row("ماء 600 مل").getByRole("cell")).toHaveText(["ماء 600 مل", "2 كرتونة + 2 قطعة", "50", "₪ 2.50"]);
  await expect(row("عصير").getByRole("cell").nth(1)).toHaveText("2 كرتونة");
  await expect(row("لوز نيء").getByRole("cell").nth(1)).toHaveText("—");
  await expect(row("لوز نيء").getByRole("cell").nth(2)).toHaveText("5.200 كغ");
  await expect(row("شاي").getByRole("cell").nth(1)).toHaveText("—");
});

test("product form: plain price labels, Arabic-keyboard digits, and a refused field is marked and focused", async ({ page }) => {
  await signIn(page);
  let sent = null;
  await page.route("**/api/v1/products", async (r) => {
    sent = r.request().postDataJSON();
    await r.fulfill({ status: 422, json: { message: "البيانات غير صالحة.", code: "VALIDATION_FAILED", errors: { selling_price: ["سعر البيع يجب أن يكون أكبر من صفر."] } } });
  });

  await page.goto("/products/new");
  await expect(page.getByText("ما تدفعه أنت للمورّد. لا يظهر للزبون.")).toBeVisible();
  await expect(page.getByLabel("اسم الصنف")).toHaveAttribute("aria-required", "true");
  await page.getByLabel("اسم الصنف").fill("شاي أخضر");
  await page.getByRole("button", { name: "بالقطعة" }).click();
  await page.getByLabel("السعر للزبون (سعر البيع)").fill("٠٫٠٠");
  await expect(page.getByLabel("السعر للزبون (سعر البيع)")).toHaveValue("0.00");
  await page.getByLabel("تكلفة الصنف عليك (سعر الشراء)").fill("١٫٧٥");
  await page.getByLabel("الكمية الموجودة الآن").fill("١٢");
  await page.getByRole("button", { name: "حفظ الصنف" }).click();

  await expect.poll(() => sent).toMatchObject({ selling_price: "0.00", cost_price: "1.75", current_stock: "12" });
  const price = page.getByLabel("السعر للزبون (سعر البيع)");
  await expect(price).toHaveAttribute("aria-invalid", "true");
  await expect(price).toHaveAccessibleDescription("سعر البيع يجب أن يكون أكبر من صفر.");
  await expect(price).toBeFocused();
});

test("cartons: a carton line says so, with its pieces, and is returned by the carton", async ({ page }) => {
  await signIn(page);
  const cartonSale = {
    ...sale,
    has_debt: false,
    debt: null,
    returns: [],
    total_amount: "115.50",
    paid_amount: "115.50",
    items: [
      { id: 41, product_id: 6, item_name: "ماء 600 مل", unit: "piece", sale_unit: "pack", pack_size: 24, quantity: "2", base_quantity: "48", returned_quantity: "0", unit_price: "54.00", line_total: "108.00" },
      { id: 42, product_id: 6, item_name: "ماء 600 مل", unit: "piece", sale_unit: "piece", pack_size: null, quantity: "3", base_quantity: "3", returned_quantity: "0", unit_price: "2.50", line_total: "7.50" },
    ],
  };
  await page.route("**/api/v1/sales/12", (r) => r.fulfill({ json: { data: cartonSale } }));

  await page.goto("/sales/12");
  const carton = page.getByRole("row").filter({ hasText: "54.00" });
  await expect(carton).toContainText("2 كرتونة");
  await expect(carton).toContainText("48 قطعة");
  await expect(carton).toContainText("/ كرتونة (24 قطعة)");

  await page.getByRole("button", { name: "مرتجع" }).click();
  const dialog = page.getByRole("dialog", { name: /مرتجع من الفاتورة/ });
  await expect(dialog.getByText("(بالكرتونة، 24 قطعة)")).toBeVisible();
  await dialog.getByRole("button", { name: "زيادة ماء 600 مل" }).first().click();
  // One carton back at its own price, not one piece.
  await expect(dialog.getByText("₪ 54.00").first()).toBeVisible();
  await expect(dialog.getByText("₪ 2.50")).toHaveCount(0);
});

test("settings: the owner saves the store details and changes the password", async ({ page }) => {
  await signIn(page);
  let storeSent = null;
  let passwordSent = null;
  const store = { id: 1, name: "بقالة الأمانة", phone: null, address: "شارع الجامعة", area: "نابلس" };
  await page.route("**/api/v1/subscription", (r) =>
    r.fulfill({ json: { data: { state: "trial", has_access: true, trial_ends_at: "2026-11-20T10:00:00Z", subscription_expires_at: null, trial_days_left: 25, support_whatsapp: "970599000000" } } }),
  );
  await page.route("**/api/v1/my-store", async (r) => {
    if (r.request().method() === "PATCH") {
      storeSent = r.request().postDataJSON();
      return r.fulfill({ json: { message: "ok", store: { ...store, ...storeSent } } });
    }
    return r.fulfill({ json: { user: owner.name, store } });
  });
  await page.route("**/api/v1/me/password", async (r) => {
    passwordSent = r.request().postDataJSON();
    if (passwordSent.current_password === "wrong-pass") {
      return r.fulfill({ status: 422, json: { message: "invalid", errors: { current_password: ["كلمة المرور الحالية غير صحيحة."] } } });
    }
    return r.fulfill({ json: { message: "ok" } });
  });

  await page.goto("/settings");
  await expect(page.getByText(/تجربة مجانية حتى/)).toBeVisible();
  await expect(page.getByRole("link", { name: "تواصل مع إدارة حسبة عبر واتساب" })).toHaveAttribute("href", /wa\.me\/970599000000/);

  await page.getByLabel(/اسم المحل/).fill("بقالة الأمانة الجديدة");
  await page.getByLabel(/هاتف المحل/).fill("٠٥٩٩١٢٣٤٥٦");
  await page.getByLabel(/العنوان/).fill("");
  await page.getByRole("button", { name: "حفظ التغييرات" }).click();
  await expect(page.getByText("حُفظت بيانات المحل.")).toBeVisible();
  expect(storeSent).toEqual({ name: "بقالة الأمانة الجديدة", phone: "0599123456", address: null, area: "نابلس" });
  // The sidebar reads the saved session user.
  await expect.poll(() => page.evaluate(() => JSON.parse(localStorage.getItem("user")).store.name)).toBe("بقالة الأمانة الجديدة");

  await page.getByRole("button", { name: "تغيير كلمة المرور" }).click();
  await expect(page.getByText("اكتب كلمة المرور الحالية.")).toBeVisible();
  expect(passwordSent).toBeNull();
  await page.locator("#pw-current").fill("wrong-pass");
  await page.getByLabel(/^كلمة المرور الجديدة/).fill("new-pass-123");
  await page.getByLabel(/تأكيد كلمة المرور الجديدة/).fill("new-pass-123");
  await page.getByRole("button", { name: "تغيير كلمة المرور" }).click();
  await expect(page.getByText("كلمة المرور الحالية غير صحيحة.")).toBeVisible();
  await page.locator("#pw-current").fill("old-pass-123");
  await page.getByRole("button", { name: "تغيير كلمة المرور" }).click();
  await expect(page.getByText("تم تغيير كلمة المرور، وسُجّل الخروج من الأجهزة الأخرى.")).toBeVisible();
  expect(passwordSent).toEqual({ current_password: "old-pass-123", password: "new-pass-123", password_confirmation: "new-pass-123" });
});

test("settings: a manager gets the subscription and password, not the store form", async ({ page }) => {
  await signIn(page, { ...owner, role: "manager" });
  await page.route("**/api/v1/subscription", (r) => r.fulfill({ json: { data: { state: "active", subscription_expires_at: "2027-01-01T10:00:00Z", support_whatsapp: null } } }));
  await page.goto("/settings");
  await expect(page.getByText(/مفعّل حتى/)).toBeVisible();
  await expect(page.getByRole("heading", { name: "تغيير كلمة المرور" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "بيانات المحل" })).toHaveCount(0);
  await expect(page.getByRole("link", { name: /الموظفون/ })).toHaveCount(0);
});

test("products: stopping asks first and says it can be undone; a stopped product comes back with one button", async ({ page }) => {
  await signIn(page);
  let product = { id: 9, name: "أرز", barcode: "555", unit: "piece", selling_price: "10.00", cost_price: null, current_stock: "4", minimum_stock: "0", status: "active" };
  const sent = [];
  await page.route("**/api/v1/products/9/movements**", (r) => r.fulfill({ json: { data: [] } }));
  await page.route("**/api/v1/products/9/deactivate", async (r) => {
    sent.push("deactivate");
    product = { ...product, status: "inactive" };
    await r.fulfill({ json: { product } });
  });
  await page.route("**/api/v1/products/9", async (r) => {
    if (r.request().method() === "PATCH") {
      sent.push(r.request().postDataJSON());
      product = { ...product, status: "active" };
    }
    await r.fulfill({ json: { data: product } });
  });

  await page.goto("/products/9");
  await page.getByRole("button", { name: "إيقاف الصنف" }).click();
  const confirm = page.getByRole("alertdialog", { name: "إيقاف «أرز»؟" });
  await expect(confirm).toContainText("تستطيع إعادته متى شئت");
  await confirm.getByRole("button", { name: "رجوع" }).click();
  expect(sent).toEqual([]);

  await page.getByRole("button", { name: "إيقاف الصنف" }).click();
  await page.getByRole("alertdialog").getByRole("button", { name: "إيقاف الصنف" }).click();
  await expect(page.getByText("هذا الصنف موقوف")).toBeVisible();
  await page.getByRole("button", { name: "إعادة تفعيل الصنف" }).click();
  await expect(page.getByRole("button", { name: "إيقاف الصنف" })).toBeVisible();
  expect(sent).toEqual(["deactivate", { status: "active" }]);
});

test("support: a complaint needs a type, subject and details; once sent it is listed with the team's reply", async ({ page }) => {
  await signIn(page, { ...owner, role: "employee" });
  let sent = null;
  let tickets = [{ id: 1, type: "account", subject: "تجديد الاشتراك", details: "كيف أجدد؟", status: "closed", reply: "تواصلنا معك.", created_at: "2026-10-20T08:00:00Z", user: { id: 1, name: owner.name } }];
  await page.route("**/api/v1/subscription", (r) => r.fulfill({ json: { data: { state: "active", subscription_expires_at: "2027-01-01T10:00:00Z", support_whatsapp: null } } }));
  await page.route("**/api/v1/support-tickets", async (r) => {
    if (r.request().method() === "POST") {
      sent = r.request().postDataJSON();
      tickets = [{ id: 2, ...sent, status: "open", reply: null, created_at: "2026-10-27T08:00:00Z", user: { id: 1, name: owner.name } }, ...tickets];
      return r.fulfill({ status: 201, json: { data: tickets[0] } });
    }
    return r.fulfill({ json: { data: tickets } });
  });

  await page.goto("/settings");
  await expect(page.getByText("تواصلنا معك.")).toBeVisible();
  await page.getByRole("button", { name: "إرسال الشكوى" }).click();
  await expect(page.getByText("اختر نوع الدعم.")).toBeVisible();
  expect(sent).toBeNull();

  await page.getByRole("button", { name: "مشكلة تقنية" }).click();
  await page.getByLabel(/موضوع المشكلة/).fill("الطابعة لا تطبع");
  await page.getByLabel(/تفاصيل المشكلة/).fill("بعد البيع تظهر رسالة خطأ.");
  await page.getByRole("button", { name: "إرسال الشكوى" }).click();
  await expect(page.getByText("وصلت شكواك إلى فريق حسبة")).toBeVisible();
  expect(sent).toEqual({ type: "technical", subject: "الطابعة لا تطبع", details: "بعد البيع تظهر رسالة خطأ." });
  await expect(page.getByRole("listitem").filter({ hasText: "الطابعة لا تطبع" })).toContainText("جديدة");
});

test("app download: the first visit opens the install guide with the newest APK; the dashboard keeps the card", async ({ page }) => {
  await signIn(page);
  await page.route("https://api.github.com/repos/abdelmoen1/micro-erp-system/releases/latest", (r) =>
    r.fulfill({
      json: {
        tag_name: "android-1.2.0_4",
        assets: [
          { name: "hisbah-1.2.0_4.apk.sha256", size: 100, browser_download_url: "https://example.test/sha" },
          { name: "hisbah.apk", size: 81_000_000, browser_download_url: "https://example.test/hisbah.apk" },
          { name: "hisbah-1.2.0_4.apk", size: 81_000_000, browser_download_url: "https://example.test/hisbah-1.2.0_4.apk" },
        ],
      },
    }),
  );

  await page.goto("/dashboard");
  const guide = page.getByRole("dialog", { name: "ابدأ بتطبيق حسبة على جوالك" });
  await expect(guide.getByRole("link", { name: /تنزيل التطبيق/ })).toHaveAttribute("href", "https://example.test/hisbah-1.2.0_4.apk");
  await expect(guide).toContainText("اسمح بالتثبيت");
  await guide.getByRole("button", { name: "لاحقاً" }).click();

  await page.reload();
  await expect(page.getByRole("dialog")).toHaveCount(0);
  const card = page.getByRole("region", { name: "تطبيق حسبة على الجوال" });
  await expect(card).toContainText("1.2.0");
  await expect(card.getByRole("link", { name: /تنزيل التطبيق/ })).toHaveAttribute("href", "https://example.test/hisbah-1.2.0_4.apk");
  // The button carries only the size; the version sits in the card's line.
  await expect(card.getByRole("link", { name: /تنزيل التطبيق/ })).toHaveText(/تنزيل التطبيق\s*81 MB/);
  await card.getByRole("button", { name: "إخفاء" }).click();
  await expect(page.getByRole("region", { name: "تطبيق حسبة على الجوال" })).toContainText("إظهار");
});

test("app download: without the GitHub API the button still serves the newest APK", async ({ page }) => {
  await signIn(page);
  await page.route("https://api.github.com/repos/abdelmoen1/micro-erp-system/releases/latest", (r) =>
    r.fulfill({ status: 403, json: { message: "API rate limit exceeded" } }),
  );
  await page.goto("/dashboard");
  const guide = page.getByRole("dialog", { name: "ابدأ بتطبيق حسبة على جوالك" });
  await expect(guide.getByRole("link", { name: /تنزيل التطبيق/ })).toHaveAttribute(
    "href",
    "https://github.com/abdelmoen1/micro-erp-system/releases/latest/download/hisbah.apk",
  );
});
