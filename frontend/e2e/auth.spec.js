import { expect, test } from "@playwright/test";

// D-32 proof on the hi-fi screens: login (W-01), the DEF-13 regression (W-02, TC-0201-02) and the
// dashboard (W-04 / W-05). The API is mocked with the real response shapes (docs/api/*.http).

const user = {
  id: 2,
  name: "علي أحمد",
  email: "owner@example.com",
  role: "owner",
  store_id: 1,
  store: { id: 1, name: "بقالة النور", timezone: "Asia/Hebron" },
};

const dashboard = {
  data: {
    period: { key: "today", from: "2026-10-21T21:00:00Z", to: "2026-10-22T20:59:59Z", timezone: "Asia/Hebron" },
    summary: {
      total_sales: "64.50",
      cash_sales: "0.00",
      credit_sales: "64.50",
      collected_at_sale: "20.00",
      new_debt: "44.50",
      total_collected_payments: "0.00",
      total_remaining_debt: "44.50",
      customers_count: 1,
      invoices_count: 1,
    },
    customers: { total: 1, with_outstanding_debts: 1 },
    payments: { total_collected: "0.00", count: 0, today: "0.00", this_month: "0.00" },
    debts: { total_debt: "44.50", total_remaining: "44.50" },
    charts: {
      sales: [{ date: "2026-10-22", amount: "64.50", cash_amount: "0.00", credit_amount: "64.50" }],
      payments: [],
      sales_hourly: Array.from({ length: 24 }, (_, h) => ({ hour: String(h).padStart(2, "0"), amount: h === 10 ? "64.50" : "0.00" })),
    },
    recent_invoices: [{ id: 1042, customer: { id: 1, name: "أبو محمد" }, total_amount: "64.50", type: "credit", status: "unpaid" }],
  },
};

/** Every other API call of the signed-in area answers with a quiet empty list. */
async function mockSignedInApi(page) {
  await page.route("**/api/v1/dashboard**", (route) => route.fulfill({ json: dashboard }));
  await page.route("**/api/v1/products/low-stock", (route) =>
    route.fulfill({ json: { data: [{ id: 5, name: "كولا علبة", unit: "piece", current_stock: "2", minimum_stock: "6" }] } }),
  );
  await page.route("**/api/v1/products?**", (route) => route.fulfill({ json: { data: [], meta: { total: 5 } } }));
}

test("owner logs in and lands on the dashboard with a stored session", async ({ page }) => {
  let sent;
  await mockSignedInApi(page);
  await page.route("**/api/v1/login", async (route) => {
    sent = route.request().postDataJSON();
    await route.fulfill({ status: 200, json: { message: "تم تسجيل دخولك بنجاح", user, token: "2|test-token" } });
  });

  await page.goto("/login");
  await page.getByLabel("البريد الإلكتروني").fill("owner@example.com");
  await page.getByLabel("كلمة المرور", { exact: true }).fill("password123");
  await page.getByRole("button", { name: "تسجيل الدخول" }).click();

  await expect(page).toHaveURL(/\/dashboard$/);
  expect(sent).toEqual({ email: "owner@example.com", password: "password123" });
  expect(await page.evaluate(() => localStorage.getItem("token"))).toBe("2|test-token");
});

test("wrong credentials show the W-01 banner and clear the password", async ({ page }) => {
  await page.route("**/api/v1/login", (route) =>
    route.fulfill({ status: 401, json: { message: "x", code: "INVALID_CREDENTIALS", errors: {}, correlation_id: "01TEST" } }),
  );

  await page.goto("/login");
  await page.getByLabel("البريد الإلكتروني").fill("owner@example.com");
  await page.getByLabel("كلمة المرور", { exact: true }).fill("wrong-password");
  await page.getByRole("button", { name: "تسجيل الدخول" }).click();

  await expect(page.getByRole("alert")).toHaveText("البريد الإلكتروني أو كلمة المرور غير صحيحة.");
  await expect(page.getByLabel("كلمة المرور", { exact: true })).toHaveValue("");
});

const registration = {
  store_name: "بقالة النور",
  owner_name: "علي أحمد",
  phone: "0599123456",
  address: "شارع السلام، الخليل",
};

test("DEF-13: the three-step /join form creates the store through the API", async ({ page }) => {
  let sent;
  await mockSignedInApi(page);
  await page.route("**/api/v1/register", async (route) => {
    sent = route.request().postDataJSON();
    await route.fulfill({ status: 201, json: { message: "تم إنشاء المتجر والمالك بنجاح", user, token: "3|new-owner" } });
  });

  await page.goto("/join");
  // Next on an empty step shows the field errors and stays on step 1.
  await page.getByRole("button", { name: "التالي" }).click();
  await expect(page.getByText("يرجى إدخال اسم المتجر.")).toBeVisible();
  await expect(page.getByText("الخطوة 1 من 3")).toBeVisible();

  await fillStoreSteps(page);
  // Back keeps what was typed.
  await page.getByRole("button", { name: "رجوع" }).click();
  await expect(page.getByLabel("رقم الهاتف")).toHaveValue("0599123456");
  await page.getByRole("button", { name: "التالي" }).click();
  await fillCredentials(page);
  await page.getByRole("button", { name: "إنشاء المتجر" }).click();

  await expect(page).toHaveURL(/\/dashboard$/);
  expect(sent).toEqual({ ...registration, email: "owner@example.com", password: "password123", password_confirmation: "password123" });
  expect(await page.evaluate(() => localStorage.getItem("token"))).toBe("3|new-owner");
});

test("a new Google user signs in, onboards and gets a store", async ({ page }) => {
  let sent;
  await mockSignedInApi(page);
  // Stand-in for Google Identity Services: its button returns an ID token when clicked.
  await page.route("https://accounts.google.com/gsi/client", (route) =>
    route.fulfill({
      contentType: "text/javascript",
      body: `window.google = { accounts: { id: {
        initialize(o) { window.__gsi = o; },
        renderButton(el) {
          const b = document.createElement("button");
          b.type = "button"; b.textContent = "Google";
          b.onclick = () => window.__gsi.callback({ credential: "id-token" });
          el.appendChild(b);
        },
      } } };`,
    }),
  );
  await page.route("**/api/v1/auth/google", (route) =>
    route.fulfill({ json: { message: "x", onboarding: { token: "sealed", name: "علي أحمد", email: "owner@gmail.com" } } }),
  );
  await page.route("**/api/v1/register/google", async (route) => {
    sent = route.request().postDataJSON();
    await route.fulfill({ status: 201, json: { message: "x", user, token: "4|google-owner" } });
  });

  await page.goto("/login");
  await page.getByRole("button", { name: "Google" }).click();

  await expect(page).toHaveURL(/\/join$/);
  await expect(page.getByLabel("اسم صاحب المتجر")).toHaveValue("علي أحمد");
  await fillStoreSteps(page);
  await expect(page.getByText("owner@gmail.com")).toBeVisible();
  await page.getByRole("button", { name: "إنشاء المتجر" }).click();

  await expect(page).toHaveURL(/\/dashboard$/);
  expect(sent).toEqual({ onboarding_token: "sealed", ...registration });
  expect(await page.evaluate(() => localStorage.getItem("token"))).toBe("4|google-owner");
});

test("DEF-13: an API validation error is shown next to its field", async ({ page }) => {
  await page.route("**/api/v1/register", (route) =>
    route.fulfill({
      status: 422,
      json: {
        message: "The email has already been taken.",
        code: "VALIDATION_FAILED",
        errors: { email: ["The email has already been taken."] },
        correlation_id: "01TEST",
      },
    }),
  );

  await page.goto("/join");
  await fillStoreSteps(page);
  await fillCredentials(page);
  await page.getByRole("button", { name: "إنشاء المتجر" }).click();

  await expect(page.getByText("الخطوة 3 من 3")).toBeVisible();
  await expect(page.getByText("هذا البريد مسجّل مسبقاً. سجّل الدخول، أو استخدم بريداً آخر.")).toBeVisible();
  await expect(page.getByText("لم يُنشأ المتجر: البريد الإلكتروني مستخدم.")).toBeVisible();
  await expect(page).toHaveURL(/\/join$/);
  expect(await page.evaluate(() => localStorage.getItem("token"))).toBeNull();
});

test("the dashboard shows the store, KPIs, low stock and the latest sale", async ({ page }) => {
  await mockSignedInApi(page);
  await page.addInitScript((u) => {
    localStorage.setItem("token", "2|test-token");
    localStorage.setItem("user", JSON.stringify(u));
  }, user);

  await page.goto("/dashboard");

  await expect(page.getByRole("heading", { name: "الرئيسية" })).toBeVisible();
  await expect(page.getByText("بقالة النور")).toBeVisible();
  await expect(page.getByText("₪ 64.50").first()).toBeVisible();
  await expect(page.getByText("₪ 44.50").first()).toBeVisible();
  await expect(page.getByText("كولا علبة")).toBeVisible();
  await expect(page.getByText("أبو محمد")).toBeVisible();
  // S3: every back-office section is a live link; Staff shows for the owner only.
  await expect(page.getByRole("link", { name: "الموظفون" })).toHaveCount(1);
  await expect(page.getByText("قريباً")).toHaveCount(0);
});

/** Steps 1 and 2 of /join: the store and owner, then location and contact. */
async function fillStoreSteps(page) {
  await page.getByLabel("اسم المتجر").fill("بقالة النور");
  await page.getByLabel("اسم صاحب المتجر").fill("علي أحمد");
  await page.getByRole("button", { name: "التالي" }).click();
  await page.getByLabel("رقم الهاتف").fill("0599123456");
  await page.getByLabel("المدينة").selectOption("الخليل");
  await page.getByLabel("عنوان المتجر").fill("شارع السلام");
  await page.getByRole("button", { name: "التالي" }).click();
}

/** Step 3 of /join with email and password. */
async function fillCredentials(page) {
  await page.getByLabel("البريد الإلكتروني").fill("owner@example.com");
  await page.getByLabel("كلمة المرور", { exact: true }).fill("password123");
  await page.getByLabel("تأكيد كلمة المرور", { exact: true }).fill("password123");
}

test("a failed low-stock request says so instead of «all products above the minimum»", async ({ page }) => {
  await mockSignedInApi(page);
  // An API without the product endpoints (the live API before S2) answers 404.
  await page.route("**/api/v1/products/low-stock", (route) =>
    route.fulfill({ status: 404, json: { message: "غير موجود", code: "NOT_FOUND", errors: {}, correlation_id: "01X" } }),
  );
  await page.addInitScript((u) => {
    localStorage.setItem("token", "2|test-token");
    localStorage.setItem("user", JSON.stringify(u));
  }, user);

  await page.goto("/dashboard");

  await expect(page.getByText("تعذّر تحميل المخزون")).toBeVisible({ timeout: 15000 });
  await expect(page.getByText("كل المنتجات فوق الحد الأدنى")).toHaveCount(0);
  await expect(page.getByText("₪ 64.50").first()).toBeVisible();
});
