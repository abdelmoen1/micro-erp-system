import { expect, test } from "@playwright/test";

// Trial / subscription expiry on the web. The server refuses every business call with
// 403 SUBSCRIPTION_EXPIRED; these tests check that the screens send the user to the renewal page,
// keep the session, offer WhatsApp when a support number is configured, and come back on renewal.

const expiredUser = {
  id: 3,
  name: "سامي",
  phone: "0599777888",
  role: "owner",
  store: { id: 9, name: "بقالة الأمل", has_access: false, subscription_state: "inactive", trial_ends_at: "2026-10-20T08:00:00Z" },
};

const summary = (overrides = {}) => ({
  state: "inactive",
  has_access: false,
  trial_ends_at: "2026-10-20T08:00:00Z",
  subscription_expires_at: null,
  trial_days_left: 0,
  support_whatsapp: "970599000000",
  ...overrides,
});

test("an expired store signs in, lands on the renewal screen, and returns once the subscription is activated", async ({ page }) => {
  let active = false;
  await page.route("**/api/v1/login", (r) => r.fulfill({ json: { message: "ok", user: expiredUser, token: "5|tok" } }));
  await page.route("**/api/v1/subscription", (r) => r.fulfill({ json: { data: summary(active ? { state: "active", has_access: true } : {}) } }));
  await page.route("**/api/v1/dashboard**", (r) => r.fulfill({ status: 200, json: { data: null } }));
  await page.route("**/api/v1/subscription/plans", (r) =>
    r.fulfill({
      json: {
        data: [{ id: 1, code: "monthly", name: "شهري", description: null, duration_months: 1, price: "50.00", currency: "ILS", features: [], limits: {} }],
        meta: { online_providers: {}, whatsapp_available: true, features: {} },
      },
    }),
  );
  let ordered = null;
  await page.route("**/api/v1/subscription/orders", (r) => {
    if (r.request().method() === "GET") return r.fulfill({ json: { data: [] } });
    ordered = r.request().postDataJSON();
    const text = encodeURIComponent("المتجر: بقالة الأمل\nرقم الطلب: HSB-ABCDEFGH23");
    return r.fulfill({
      status: 201,
      json: { data: { id: 7, reference: "HSB-ABCDEFGH23", status: "pending_contact", amount: "50.00", currency: "ILS", whatsapp_url: `https://wa.me/970599000000?text=${text}` } },
    });
  });

  await page.goto("/login");
  await page.getByLabel("رقم الجوال").fill("0599123456");
  await page.getByLabel("كلمة المرور", { exact: true }).fill("not-a-real-password");
  await page.getByRole("button", { name: "تسجيل الدخول" }).click();

  await expect(page).toHaveURL(/\/subscription-expired$/);
  await expect(page.getByRole("heading", { name: "انتهت الفترة التجريبية" })).toBeVisible();
  await expect(page.getByText("بقالة الأمل")).toBeVisible();
  await expect(page.getByText("بياناتك محفوظة كما هي")).toBeVisible();

  // The owner buys on the website: server plans, then a WhatsApp request with a reference.
  // Nothing is activated by the request itself.
  await expect(page.getByText("50.00")).toBeVisible();
  await expect(page.getByRole("button", { name: /ادفع إلكترونياً/ })).toHaveCount(0);
  await page.evaluate(() => {
    window.__opened = [];
    window.open = (u) => window.__opened.push(u);
  });
  await page.getByRole("button", { name: /لا تملك بطاقة دفع؟ تواصل معنا عبر واتساب/ }).click();
  await expect(page.getByText("HSB-ABCDEFGH23")).toBeVisible();
  expect(ordered).toEqual({ plan_id: 1, channel: "manual_whatsapp" });
  const opened = await page.evaluate(() => window.__opened[0]);
  expect(opened).toMatch(/^https:\/\/wa\.me\/970599000000\?text=/);
  expect(decodeURIComponent(opened)).toContain("HSB-ABCDEFGH23");

  // Not yet activated: says so and stays.
  await page.getByRole("button", { name: "تحقق من جديد" }).click();
  await expect(page.getByText("لم يُفعَّل الاشتراك بعد")).toBeVisible();
  await expect(page).toHaveURL(/\/subscription-expired$/);
  expect(await page.evaluate(() => localStorage.getItem("token"))).toBe("5|tok");

  // The admin activates it.
  active = true;
  await page.getByRole("button", { name: "تحقق من جديد" }).click();
  await expect(page).toHaveURL(/\/dashboard$/);
});

test("a 403 SUBSCRIPTION_EXPIRED on any store page goes to the renewal screen; staff get no WhatsApp button without a number", async ({ page }) => {
  // A manager (not the owner, who buys): the support path without a number.
  await page.addInitScript((u) => {
    localStorage.setItem("token", "5|tok");
    localStorage.setItem("user", JSON.stringify({ ...u, role: "manager", store: { ...u.store, has_access: true } }));
  }, expiredUser);
  await page.route("**/api/v1/customers**", (r) =>
    r.fulfill({ status: 403, json: { message: "انتهت الفترة التجريبية لمتجرك.", code: "SUBSCRIPTION_EXPIRED", errors: {}, details: summary({ support_whatsapp: null }) } }),
  );
  await page.route("**/api/v1/subscription", (r) => r.fulfill({ json: { data: summary({ support_whatsapp: null, state: "expired", subscription_expires_at: "2026-10-22T21:59:59Z" }) } }));

  await page.goto("/customers");
  await expect(page).toHaveURL(/\/subscription-expired$/);
  await expect(page.getByRole("heading", { name: "انتهى اشتراك متجرك" })).toBeVisible();
  await expect(page.getByRole("link", { name: "تواصل معنا عبر واتساب" })).toHaveCount(0);
  await expect(page.getByText("تواصل مع إدارة حسبة لتفعيل الاشتراك.")).toBeVisible();
  // Never a dead end: the store to name, and what happens after paying.
  await expect(page.getByText("اذكر هذه البيانات عند التواصل:")).toBeVisible();
  await expect(page.getByText(expiredUser.phone)).toBeVisible();
  await expect(page.getByRole("button", { name: "نسخ البيانات" })).toBeVisible();
  await expect(page.getByText("ثم اضغط «تحقق من جديد» لتعود إلى متجرك.", { exact: false })).toBeVisible();
});
