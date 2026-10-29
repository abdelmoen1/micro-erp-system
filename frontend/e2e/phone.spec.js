import { expect, test } from "@playwright/test";

// Sign-in by mobile number on the web: an older account by its e-mail, a forgotten password and
// sign-up with the SMS code, and adding the number to an older account in Settings.

const user = { id: 1, name: "علي أحمد", phone: "0599123456", role: "owner", store: { id: 1, name: "بقالة النور" } };

const options = (otp) => (route) => route.fulfill({ json: { data: { login: "phone", otp } } });

async function mockDashboard(page) {
  await page.route("**/api/v1/dashboard**", (r) => r.fulfill({ json: { data: null } }));
  await page.route("**/api/v1/subscription", (r) => r.fulfill({ json: { data: { state: "trial", has_access: true } } }));
  await page.route("**/api/v1/products/low-stock**", (r) => r.fulfill({ json: { data: [] } }));
  await page.route("**/api/v1/products?**", (r) => r.fulfill({ json: { data: [], meta: { total: 0 } } }));
}

test("an e-mail is not a sign-in; no reset link while codes are off", async ({ page }) => {
  let sent;
  await mockDashboard(page);
  await page.route("**/api/v1/auth/options", options(false));
  await page.route("**/api/v1/login", async (route) => {
    sent = route.request().postDataJSON();
    await route.fulfill({ json: { message: "ok", user, token: "2|t" } });
  });

  await page.goto("/login");
  await expect(page.getByRole("link", { name: "نسيت كلمة المرور؟" })).toHaveCount(0);
  await page.getByLabel("رقم الجوال").fill("12345");
  await page.getByLabel("كلمة المرور", { exact: true }).fill("password123");
  await page.getByRole("button", { name: "تسجيل الدخول" }).click();
  await expect(page.getByText("رقم الجوال 10 أرقام يبدأ بـ 05، مثل 0599123456.")).toBeVisible();
  expect(sent).toBeUndefined();

  await page.getByLabel("رقم الجوال").fill("old@shop.ps");
  await page.getByRole("button", { name: "تسجيل الدخول" }).click();
  await expect(page.getByText("رقم الجوال 10 أرقام يبدأ بـ 05، مثل 0599123456.")).toBeVisible();
  expect(sent).toBeUndefined();

  await page.getByLabel("رقم الجوال").fill("0599 123 456");
  await page.getByRole("button", { name: "تسجيل الدخول" }).click();
  await expect(page).toHaveURL(/\/dashboard$/);
  expect(sent).toEqual({ login: "0599123456", password: "password123" });
});

test("a forgotten password: the number, the SMS code and a new password, then back to sign in", async ({ page }) => {
  const calls = [];
  await page.route("**/api/v1/auth/options", options(true));
  await page.route("**/api/v1/auth/otp", async (route) => {
    calls.push(["otp", route.request().postDataJSON()]);
    await route.fulfill({ json: { message: "sent", data: { expires_in: 600, resend_in: 60 } } });
  });
  await page.route("**/api/v1/auth/password/reset", async (route) => {
    calls.push(["reset", route.request().postDataJSON()]);
    await route.fulfill({ json: { message: "تم" } });
  });

  await page.goto("/login");
  await page.getByRole("link", { name: "نسيت كلمة المرور؟" }).click();
  await expect(page).toHaveURL(/\/forgot$/);

  await page.getByLabel("رقم الجوال").fill("٠٥٩٩ ١٢٣ ٤٥٦");
  await page.getByRole("button", { name: "أرسل الرمز" }).click();
  await expect(page.getByText("059•••••56")).toBeVisible();
  await expect(page.getByRole("button", { name: /رمز جديد بعد/ })).toBeDisabled();

  await page.getByLabel("رمز التأكيد").fill("123456");
  await page.getByLabel("كلمة المرور الجديدة", { exact: true }).fill("New-pass-2026");
  await page.getByLabel("تأكيد كلمة المرور الجديدة").fill("New-pass-2026");
  await page.getByRole("button", { name: "حفظ كلمة المرور الجديدة" }).click();

  await expect(page).toHaveURL(/\/login\?phone=0599123456&reset=1$/);
  await expect(page.getByText("تم تغيير كلمة المرور. سجّل الدخول برقم جوالك وكلمة المرور الجديدة.")).toBeVisible();
  await expect(page.getByLabel("رقم الجوال")).toHaveValue("0599123456");
  expect(calls).toEqual([
    ["otp", { phone: "0599123456", purpose: "reset" }],
    ["reset", { phone: "0599123456", otp_code: "123456", password: "New-pass-2026", password_confirmation: "New-pass-2026" }],
  ]);
});

test("with SMS codes on, /join confirms the number with a code before the store is made", async ({ page }) => {
  let otp;
  let registered;
  await mockDashboard(page);
  await page.route("**/api/v1/auth/options", options(true));
  await page.route("**/api/v1/auth/otp", async (route) => {
    otp = route.request().postDataJSON();
    await route.fulfill({ json: { message: "sent", data: { resend_in: 60 } } });
  });
  await page.route("**/api/v1/register", async (route) => {
    registered = route.request().postDataJSON();
    await route.fulfill({ status: 201, json: { message: "x", user, token: "3|owner" } });
  });

  await page.goto("/join");
  await page.getByLabel("اسم المتجر").fill("بقالة النور");
  await page.getByLabel("اسم صاحب المتجر").fill("علي أحمد");
  await page.getByRole("button", { name: "التالي" }).click();
  await page.getByLabel("رقم جوالك (تسجّل الدخول به)").fill("+970 599 123 456");
  await page.getByLabel("المدينة").selectOption("الخليل");
  await page.getByLabel("عنوان المتجر").fill("شارع السلام");
  await page.getByRole("button", { name: "التالي" }).click();
  await expect(page.getByText("جميع الحقول مطلوبة")).toBeVisible();
  await page.getByLabel("كلمة المرور", { exact: true }).fill("password123");
  await page.getByLabel("تأكيد كلمة المرور", { exact: true }).fill("password123");
  await page.getByRole("button", { name: "أرسل رمز التأكيد" }).click();

  expect(otp).toEqual({ phone: "0599123456", purpose: "register" });
  expect(registered).toBeUndefined();
  await page.getByLabel("رمز التأكيد").fill("482913");
  await page.getByRole("button", { name: "تأكيد الرمز وإنشاء المتجر" }).click();

  await expect(page).toHaveURL(/\/dashboard$/);
  expect(registered).toEqual({
    store_name: "بقالة النور",
    owner_name: "علي أحمد",
    owner_phone: "0599123456",
    phone: "0599123456",
    address: "شارع السلام، الخليل",
    area: "الخليل",
    password: "password123",
    password_confirmation: "password123",
    otp_code: "482913",
  });
});

test("the sign-in number is changed in Settings", async ({ page }) => {
  let sent;
  const old = { ...user, phone: "0599000001" };
  await page.addInitScript((u) => {
    localStorage.setItem("token", "2|test-token");
    localStorage.setItem("user", JSON.stringify(u));
  }, old);
  await page.route("**/api/v1/auth/options", options(false));
  await page.route("**/api/v1/support-tickets", (r) => r.fulfill({ json: { data: [] } }));
  await page.route("**/api/v1/sync/conflicts**", (r) => r.fulfill({ json: { data: [], meta: {}, open_count: 0 } }));
  await page.route("**/api/v1/my-store", (r) => r.fulfill({ json: { store: { id: 1, name: "بقالة النور" } } }));
  await page.route("**/api/v1/subscription", (r) => r.fulfill({ json: { data: { state: "trial", has_access: true } } }));
  await page.route("**/api/v1/me/phone", async (route) => {
    sent = route.request().postDataJSON();
    await route.fulfill({ json: { message: "تم", user: { ...old, phone: "0599123456" } } });
  });

  await page.goto("/settings");
  const section = page.locator("form").filter({ has: page.getByRole("heading", { name: "رقم الجوال للدخول" }) });
  await section.getByLabel("رقم الجوال").fill("059-912-3456");
  await section.getByLabel("كلمة المرور الحالية").fill("password123");
  await section.getByRole("button", { name: "حفظ الرقم" }).click();

  await expect(section.getByText("تدخل الآن بالرقم")).toBeVisible();
  expect(sent).toEqual({ phone: "0599123456", current_password: "password123" });
  expect(JSON.parse(await page.evaluate(() => localStorage.getItem("user"))).phone).toBe("0599123456");
});
