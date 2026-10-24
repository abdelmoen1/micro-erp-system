import { expect, test } from "@playwright/test";

// Platform owner area (/admin). The API is mocked with the shapes of the Laravel admin resources;
// the server is what actually refuses non-admins, these tests check what each screen shows and sends.

const admin = { id: 1, name: "إدارة حسبة", email: "admin@hisbah.ps", role: "owner", is_platform_admin: true, store: { id: 1, name: "حسبة" } };
const owner = { id: 2, name: "علي أحمد", email: "ali@shop.ps", role: "owner", is_platform_admin: false, store: { id: 5, name: "بقالة الأمانة" } };

async function signIn(page, user) {
  await page.addInitScript((u) => {
    localStorage.setItem("token", "2|test-token");
    localStorage.setItem("user", JSON.stringify(u));
  }, user);
}

const store = {
  id: 5,
  name: "بقالة الأمانة",
  phone: "0599111222",
  address: "غزة، الرمال",
  timezone: "Asia/Gaza",
  created_at: "2026-10-12T09:00:00Z",
  days_since_registration: 12,
  owner: { id: 2, name: "علي أحمد", email: "ali@shop.ps", phone: "0599333444", status: "active" },
  status: "active",
  suspension_reason: null,
  status_changed_at: null,
  subscription: { status: "inactive", state: "inactive", started_at: null, expires_at: null, changed_at: null },
  users_count: 2,
  products_count: 3,
};

const overview = {
  stores: { total: 4, active: 3, suspended: 1, registered_last_30_days: 2 },
  subscriptions: { active: 1, expired: 1, inactive: 2 },
  products: { store_rows: 40, catalog_items: 12 },
};

const meta = { current_page: 1, last_page: 1, total: 1, per_page: 20 };

test("signed out, /admin goes to the admin sign-in, and the platform admin lands on the dashboard", async ({ page }) => {
  let sent = null;
  await page.route("**/api/v1/login", async (r) => {
    sent = r.request().postDataJSON();
    await r.fulfill({ json: { message: "ok", user: admin, token: "9|admin-token" } });
  });
  await page.route("**/api/v1/admin/overview", (r) => r.fulfill({ json: { data: overview } }));
  await page.route(/\/api\/v1\/admin\/stores(\?.*)?$/, (r) => r.fulfill({ json: { data: [store], meta } }));

  await page.goto("/admin/stores/5");
  await expect(page).toHaveURL(/\/admin\/login$/);
  await expect(page.getByRole("heading", { name: "دخول إدارة المنصة" })).toBeVisible();

  await page.getByLabel("البريد الإلكتروني").fill("owner@example.test");
  await page.getByLabel("كلمة المرور", { exact: true }).fill("not-a-real-password");
  await page.getByRole("button", { name: "دخول الإدارة" }).click();

  await expect(page).toHaveURL(/\/admin$/);
  await expect(page.getByRole("heading", { name: "المتاجر" })).toBeVisible();
  expect(sent).toEqual({ email: "owner@example.test", password: "not-a-real-password" });
  expect(await page.evaluate(() => localStorage.getItem("token"))).toBe("9|admin-token");
});

test("a store account is refused on the admin sign-in and signed out again", async ({ page }) => {
  let loggedOut = false;
  await page.route("**/api/v1/login", (r) => r.fulfill({ json: { message: "ok", user: owner, token: "3|store-token" } }));
  await page.route("**/api/v1/logout", async (r) => {
    loggedOut = r.request().headers().authorization === "Bearer 3|store-token";
    await r.fulfill({ json: { message: "ok" } });
  });

  await page.goto("/admin/login");
  await page.getByLabel("البريد الإلكتروني").fill("ali@shop.ps");
  await page.getByLabel("كلمة المرور", { exact: true }).fill("not-a-real-password");
  await page.getByRole("button", { name: "دخول الإدارة" }).click();

  await expect(page.getByText("هذا الحساب حساب متجر، وليس حساب إدارة المنصة.")).toBeVisible();
  await expect(page).toHaveURL(/\/admin\/login$/);
  expect(loggedOut).toBe(true);
  expect(await page.evaluate(() => localStorage.getItem("token"))).toBeNull();
});

test("a store owner who opens /admin gets the refusal screen and no admin link", async ({ page }) => {
  await signIn(page, owner);
  let adminCalls = 0;
  await page.route("**/api/v1/admin/**", (r) => {
    adminCalls++;
    return r.fulfill({ status: 403, json: { message: "هذه الصفحة لمالك المنصة فقط.", code: "FORBIDDEN", errors: {} } });
  });
  await page.route("**/api/v1/users", (r) => r.fulfill({ json: { data: [] } }));

  await page.goto("/admin");
  await expect(page.getByText("هذه الصفحات لمالك المنصة فقط")).toBeVisible();
  expect(adminCalls).toBe(0);

  await page.goto("/staff");
  await expect(page.getByRole("heading", { name: "الموظفون" })).toBeVisible();
  await expect(page.getByRole("link", { name: "إدارة المنصة" })).toHaveCount(0);
});

test("the platform admin sees counts and stores, and filters by subscription state", async ({ page }) => {
  await signIn(page, admin);
  const requests = [];
  await page.route("**/api/v1/admin/overview", (r) => r.fulfill({ json: { data: overview } }));
  await page.route(/\/api\/v1\/admin\/stores(\?.*)?$/, (r) => {
    requests.push(new URL(r.request().url()).searchParams.get("subscription"));
    return r.fulfill({ json: { data: [store], meta } });
  });

  await page.goto("/admin");
  await expect(page.getByRole("heading", { name: "المتاجر" })).toBeVisible();
  const counts = page.getByRole("region", { name: "ملخص المنصة" });
  await expect(counts.getByText("حسابات موقوفة")).toBeVisible();
  await expect(counts).toContainText("4");

  const table = page.getByRole("table", { name: "المتاجر المسجّلة" });
  await expect(table.getByRole("link", { name: "بقالة الأمانة" })).toBeVisible();
  await expect(table).toContainText("قبل 12 يوماً");
  await expect(table).toContainText("الحساب مفعّل");
  await expect(table).toContainText("بلا اشتراك");

  await page.getByRole("group", { name: "حالة الاشتراك" }).getByRole("button", { name: /منتهٍ/ }).click();
  await expect.poll(() => requests.at(-1)).toBe("expired");
});

test("suspending the account and activating the subscription are separate requests", async ({ page }) => {
  await signIn(page, admin);
  let current = { ...store, members: [{ id: 2, name: "علي أحمد", email: "ali@shop.ps", role: "owner", status: "active" }], active_products_count: 2, history: [] };
  const writes = [];

  await page.route("**/api/v1/admin/stores/5", (r) => r.fulfill({ json: { data: current } }));
  await page.route(/\/api\/v1\/admin\/stores\/5\/products(\?.*)?$/, (r) =>
    r.fulfill({
      json: {
        data: [{ id: 9, name: "حليب 1 لتر", barcode: "6291041500213", unit: "piece", selling_price: "6.00", cost_price: "4.50", current_stock: "30", minimum_stock: "5", is_low_stock: false, status: "active", catalog_product: { id: 3 } }],
        meta,
      },
    }),
  );
  await page.route("**/api/v1/admin/stores/5/status", async (r) => {
    const body = r.request().postDataJSON();
    writes.push(["status", body]);
    current = { ...current, status: body.status, suspension_reason: body.reason ?? null, status_changed_at: "2026-10-24T10:00:00Z", status_changed_by: { id: 1, name: admin.name } };
    await r.fulfill({ json: { data: current } });
  });
  await page.route("**/api/v1/admin/stores/5/subscription", async (r) => {
    const body = r.request().postDataJSON();
    writes.push(["subscription", body]);
    current = { ...current, subscription: { status: "active", state: "active", started_at: "2026-10-24T10:00:00Z", expires_at: `${body.expires_at}T21:59:59Z`, changed_at: "2026-10-24T10:00:00Z" } };
    await r.fulfill({ json: { data: current } });
  });

  await page.goto("/admin/stores/5");
  await expect(page.getByRole("heading", { name: "بقالة الأمانة", level: 1 })).toBeVisible();
  const access = page.getByRole("region", { name: "حساب المتجر" });
  const subscription = page.getByRole("region", { name: "الاشتراك" });
  await expect(access).toContainText("مفعّل");
  await expect(subscription).toContainText("غير مشترك");
  await expect(page.getByRole("table", { name: "منتجات بقالة الأمانة" })).toContainText("₪ 4.50");

  await access.getByRole("button", { name: "إيقاف الحساب" }).click();
  const confirm = page.getByRole("alertdialog", { name: /إيقاف حساب بقالة الأمانة/ });
  await confirm.getByRole("textbox").fill("لم تصل دفعة أكتوبر");
  await confirm.getByRole("button", { name: "إيقاف الحساب" }).click();
  await expect(access).toContainText("موقوف");
  await expect(access).toContainText("لم تصل دفعة أكتوبر");
  // The subscription panel did not change.
  await expect(subscription).toContainText("غير مشترك");

  await subscription.getByRole("button", { name: "تفعيل الاشتراك" }).click();
  const dialog = page.getByRole("dialog", { name: /تفعيل اشتراك بقالة الأمانة/ });
  await dialog.getByLabel(/ينتهي في نهاية يوم/).fill("2027-01-31");
  await dialog.getByRole("button", { name: "تفعيل الاشتراك" }).click();
  await expect(subscription).toContainText("فعّال");
  await expect(access).toContainText("موقوف");

  expect(writes).toEqual([
    ["status", { status: "suspended", reason: "لم تصل دفعة أكتوبر" }],
    ["subscription", { status: "active", expires_at: "2027-01-31" }],
  ]);
});

test("the products monitor shows one row per store, each with its own price and stock", async ({ page }) => {
  await signIn(page, admin);
  const row = (id, storeId, storeName, address, price, stock) => ({
    id,
    name: "حليب 1 لتر",
    barcode: "6291041500213",
    unit: "piece",
    selling_price: price,
    cost_price: "4.50",
    current_stock: stock,
    minimum_stock: "5",
    is_low_stock: Number(stock) <= 5,
    status: "active",
    catalog_product: { id: 3, barcode: "6291041500213", name: "حليب 1 لتر", unit: "piece" },
    store: { id: storeId, name: storeName, address, phone: null, status: "active" },
  });
  let lastQuery = null;
  await page.route(/\/api\/v1\/admin\/products(\?.*)?$/, (r) => {
    lastQuery = new URL(r.request().url()).searchParams;
    return r.fulfill({ json: { data: [row(1, 5, "بقالة الأمانة", "غزة", "6.00", "30"), row(2, 6, "سوبرماركت النور", "رفح", "7.25", "4")], meta: { ...meta, total: 2 } } });
  });

  await page.goto("/admin/products");
  const table = page.getByRole("table", { name: "المنتجات في كل المتاجر" });
  await expect(table.getByRole("row")).toHaveCount(3);
  await expect(table.getByRole("row").nth(1)).toContainText("₪ 6.00");
  await expect(table.getByRole("row").nth(1)).toContainText("غزة");
  await expect(table.getByRole("row").nth(2)).toContainText("₪ 7.25");
  await expect(table.getByRole("row").nth(2)).toContainText("رفح");

  await page.getByPlaceholder("اسم المتجر أو عنوانه").fill("رفح");
  await expect.poll(() => lastQuery?.get("store")).toBe("رفح");
});
