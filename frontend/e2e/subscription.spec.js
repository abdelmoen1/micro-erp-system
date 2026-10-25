import { expect, test } from "@playwright/test";

// Trial / subscription expiry on the web. The server refuses every business call with
// 403 SUBSCRIPTION_EXPIRED; these tests check that the screens send the user to the renewal page,
// keep the session, offer WhatsApp when a support number is configured, and come back on renewal.

const expiredUser = {
  id: 3,
  name: "سامي",
  email: "sami@shop.ps",
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

  await page.goto("/login");
  await page.getByLabel("البريد الإلكتروني").fill("sami@shop.ps");
  await page.getByLabel("كلمة المرور", { exact: true }).fill("not-a-real-password");
  await page.getByRole("button", { name: "تسجيل الدخول" }).click();

  await expect(page).toHaveURL(/\/subscription-expired$/);
  await expect(page.getByRole("heading", { name: "انتهت الفترة التجريبية" })).toBeVisible();
  await expect(page.getByText("بقالة الأمل")).toBeVisible();
  await expect(page.getByText("بياناتك محفوظة كما هي")).toBeVisible();

  const whatsapp = page.getByRole("link", { name: "تواصل معنا عبر واتساب" });
  const href = await whatsapp.getAttribute("href");
  expect(href).toMatch(/^https:\/\/wa\.me\/970599000000\?text=/);
  expect(decodeURIComponent(href)).toContain("بقالة الأمل");
  expect(await whatsapp.getAttribute("target")).toBe("_blank");

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

test("a 403 SUBSCRIPTION_EXPIRED on any store page goes to the renewal screen; no WhatsApp button without a number", async ({ page }) => {
  await page.addInitScript((u) => {
    localStorage.setItem("token", "5|tok");
    localStorage.setItem("user", JSON.stringify({ ...u, store: { ...u.store, has_access: true } }));
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
});
