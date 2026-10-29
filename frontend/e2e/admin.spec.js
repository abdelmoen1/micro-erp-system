import { expect, test } from "@playwright/test";

// Platform owner area (/admin). The API is mocked with the shapes of the Laravel admin resources;
// the server is what actually refuses non-admins, these tests check what each screen shows and sends.

const admin = { id: 1, name: "إدارة حسبة", phone: "0592288354", role: "owner", is_platform_admin: true, store: { id: 1, name: "حسبة" } };
const owner = { id: 2, name: "علي أحمد", phone: "0599333444", role: "owner", is_platform_admin: false, store: { id: 5, name: "بقالة الأمانة" } };

async function signIn(page, user) {
  await page.addInitScript((u) => {
    localStorage.setItem("token", "2|test-token");
    localStorage.setItem("user", JSON.stringify(u));
  }, user);
  // The sidebar counts new complaints on every admin page; a test that needs them routes its own.
  await page.route("**/api/v1/admin/support-tickets**", (r) => r.fulfill({ json: { data: [], meta: { current_page: 1, last_page: 1, total: 0, open_count: 0 } } }));
}

const store = {
  id: 5,
  name: "بقالة الأمانة",
  phone: "0599111222",
  address: "غزة، الرمال",
  timezone: "Asia/Gaza",
  created_at: "2026-10-12T09:00:00Z",
  days_since_registration: 12,
  owner: { id: 2, name: "علي أحمد", phone: "0599333444", status: "active" },
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

  await page.getByLabel("رقم الجوال").fill("059 228 8354");
  await page.getByLabel("كلمة المرور", { exact: true }).fill("not-a-real-password");
  await page.getByRole("button", { name: "دخول الإدارة" }).click();

  await expect(page).toHaveURL(/\/admin$/);
  await expect(page.getByRole("heading", { name: "المتاجر" })).toBeVisible();
  expect(sent).toEqual({ login: "0592288354", password: "not-a-real-password" });
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
  await page.getByLabel("رقم الجوال").fill("0599333444");
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
  const accounts = page.getByRole("group", { name: "حساب المتجر" });
  await expect(accounts.getByRole("button", { name: /كل المتاجر/ })).toContainText("4");
  await expect(accounts.getByRole("button", { name: /موقوفة/ })).toContainText("1");
  await expect(accounts.getByRole("button", { name: /كل المتاجر/ })).toHaveAttribute("aria-pressed", "true");

  const table = page.getByRole("table", { name: "المتاجر المسجّلة" });
  await expect(table.getByRole("link", { name: "بقالة الأمانة" })).toBeVisible();
  await expect(table).toContainText("قبل 12 يوماً");
  await expect(table.getByRole("switch", { name: "حساب بقالة الأمانة" })).toHaveAttribute("aria-checked", "true");
  await expect(table).toContainText("بلا اشتراك");

  const expired = page.getByRole("group", { name: "الاشتراك" }).getByRole("button", { name: /منتهٍ/ });
  await expired.click();
  await expect.poll(() => requests.at(-1)).toBe("expired");
  await expect(expired).toHaveAttribute("aria-pressed", "true");

  // «تحديث» fetches the list again (a store that just registered on the phone appears).
  const before = requests.length;
  await page.getByRole("button", { name: "تحديث" }).click();
  await expect.poll(() => requests.length).toBeGreaterThan(before);
});

test("suspending the account and activating the subscription are separate requests", async ({ page }) => {
  await signIn(page, admin);
  let current = { ...store, members: [{ id: 2, name: "علي أحمد", phone: "0599333444", role: "owner", status: "active" }], active_products_count: 2, history: [] };
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

  const toggle = access.getByRole("switch", { name: "حساب بقالة الأمانة" });
  await expect(toggle).toHaveAttribute("aria-checked", "true");
  await toggle.click();
  const confirm = page.getByRole("alertdialog", { name: /إيقاف حساب بقالة الأمانة/ });
  await confirm.getByRole("textbox").fill("لم تصل دفعة أكتوبر");
  await confirm.getByRole("button", { name: "إيقاف الحساب" }).click();
  await expect(access).toContainText("موقوف");
  await expect(access).toContainText("لم تصل دفعة أكتوبر");
  await expect(toggle).toHaveAttribute("aria-checked", "false");
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

test("deleting a store needs its exact name, then returns to the list without it", async ({ page }) => {
  await signIn(page, admin);
  const detail = { ...store, members: [{ id: 2, name: "علي أحمد", phone: "0599333444", role: "owner", status: "active" }], active_products_count: 2, history: [] };
  let deleted = false;
  const deletes = [];

  await page.route("**/api/v1/admin/stores/5", async (r) => {
    if (r.request().method() === "DELETE") {
      deletes.push(r.request().postDataJSON());
      deleted = true;
      return r.fulfill({ json: { message: "تم حذف المتجر وكل بياناته نهائياً", data: { id: 5, removed: { users: 2 } } } });
    }
    return deleted ? r.fulfill({ status: 404, json: { message: "غير موجود", code: "NOT_FOUND", errors: {} } }) : r.fulfill({ json: { data: detail } });
  });
  await page.route(/\/api\/v1\/admin\/stores\/5\/products(\?.*)?$/, (r) => r.fulfill({ json: { data: [], meta } }));
  await page.route("**/api/v1/admin/overview", (r) => r.fulfill({ json: { data: overview } }));
  await page.route(/\/api\/v1\/admin\/stores(\?.*)?$/, (r) => r.fulfill({ json: { data: deleted ? [] : [store], meta: { ...meta, total: deleted ? 0 : 1 } } }));

  await page.goto("/admin/stores/5");
  await page.getByRole("region", { name: "حذف المتجر نهائياً" }).getByRole("button", { name: "حذف المتجر" }).click();
  const dialog = page.getByRole("alertdialog", { name: /حذف بقالة الأمانة نهائياً/ });
  await expect(dialog).toContainText("حسابات الأعضاء (2)");
  const confirm = dialog.getByRole("button", { name: "حذف نهائياً" });
  const name = dialog.getByLabel(/اكتب اسم المتجر/);
  await expect(name).toBeFocused();

  await name.fill("بقالة");
  await expect(confirm).toBeDisabled();
  await dialog.getByRole("button", { name: "رجوع" }).click();
  await expect(dialog).toBeHidden();
  expect(deletes).toEqual([]);

  await page.getByRole("button", { name: "حذف المتجر" }).click();
  await dialog.getByLabel(/اكتب اسم المتجر/).fill("بقالة الأمانة");
  await confirm.click();

  await expect(page).toHaveURL(/\/admin$/);
  await expect(page.getByRole("status").filter({ hasText: "حُذف متجر «بقالة الأمانة»" })).toBeVisible();
  await expect(page.getByRole("link", { name: "بقالة الأمانة" })).toHaveCount(0);
  expect(deletes).toEqual([{ confirm_name: "بقالة الأمانة" }]);
});

test("the account switch in the stores list: switching on is immediate, switching off asks first", async ({ page }) => {
  await signIn(page, admin);
  let rows = [
    { ...store, id: 5, name: "بقالة الأمانة", status: "active" },
    { ...store, id: 6, name: "سوبرماركت النور", status: "suspended" },
  ];
  const writes = [];
  await page.route("**/api/v1/admin/overview", (r) => r.fulfill({ json: { data: overview } }));
  await page.route(/\/api\/v1\/admin\/stores(\?.*)?$/, (r) => r.fulfill({ json: { data: rows, meta: { ...meta, total: 2 } } }));
  await page.route(/\/api\/v1\/admin\/stores\/\d+\/status$/, async (r) => {
    const id = Number(r.request().url().match(/stores\/(\d+)\/status/)[1]);
    const body = r.request().postDataJSON();
    writes.push([id, body]);
    rows = rows.map((s) => (s.id === id ? { ...s, status: body.status } : s));
    await r.fulfill({ json: { data: rows.find((s) => s.id === id) } });
  });

  await page.goto("/admin");
  const nour = page.getByRole("switch", { name: "حساب سوبرماركت النور" });
  const amana = page.getByRole("switch", { name: "حساب بقالة الأمانة" });
  await expect(nour).toHaveAttribute("aria-checked", "false");
  await expect(amana).toHaveAttribute("aria-checked", "true");

  // On: no dialog, one request.
  await nour.click();
  await expect(nour).toHaveAttribute("aria-checked", "true");
  await expect(page.getByRole("alertdialog")).toHaveCount(0);

  // Off: confirmation first; "رجوع" sends nothing.
  await amana.click();
  const confirm = page.getByRole("alertdialog", { name: /إيقاف حساب بقالة الأمانة/ });
  await confirm.getByRole("button", { name: "رجوع" }).click();
  await expect(amana).toHaveAttribute("aria-checked", "true");
  await amana.click();
  await page.getByRole("alertdialog", { name: /إيقاف حساب بقالة الأمانة/ }).getByRole("button", { name: "إيقاف الحساب" }).click();
  await expect(amana).toHaveAttribute("aria-checked", "false");

  expect(writes).toEqual([
    [6, { status: "active" }],
    [5, { status: "suspended" }],
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

test("the shared catalog lists each barcode once and compares one item's prices across stores", async ({ page }) => {
  await signIn(page, admin);
  const offer = (id, storeId, storeName, area, price, stock, status = "active") => ({
    id,
    name: "حليب 1 لتر",
    barcode: "6291041500213",
    unit: "piece",
    selling_price: price,
    cost_price: "4.50",
    current_stock: stock,
    minimum_stock: "5",
    is_low_stock: false,
    status,
    store: { id: storeId, name: storeName, address: null, area, phone: null, status: "active" },
  });
  let lastQuery = null;
  await page.route(/\/api\/v1\/admin\/catalog-products(\?.*)?$/, (r) => {
    lastQuery = new URL(r.request().url()).searchParams;
    return r.fulfill({
      json: {
        data: [
          { id: 3, barcode: "6291041500213", name: "حليب 1 لتر", unit: "piece", stores_count: 3, active_stores_count: 2, price_min: "6.00", price_max: "7.25" },
          { id: 4, barcode: "0012345678905", name: "ماء 600 مل", unit: "piece", stores_count: 1, active_stores_count: 1, price_min: "2.00", price_max: "2.00" },
        ],
        meta: { ...meta, total: 2 },
      },
    });
  });
  await page.route("**/api/v1/admin/catalog-products/3", (r) =>
    r.fulfill({
      json: {
        data: {
          id: 3, barcode: "6291041500213", name: "حليب 1 لتر", unit: "piece", created_at: "2026-10-20T09:00:00Z", stores_count: 3,
          comparison: { active_stores_count: 2, price_min: "6.00", price_max: "7.25", price_spread: "1.25" },
          offers: [offer(9, 7, "ميني ماركت", "خان يونس", "5.00", "2", "inactive"), offer(1, 5, "بقالة الأمانة", "غزة", "6.00", "30"), offer(2, 6, "سوبرماركت النور", "رفح", "7.25", "4")],
        },
      },
    }),
  );

  await page.goto("/admin");
  await page.getByRole("link", { name: "الكتالوج المشترك" }).click();
  const list = page.getByRole("table", { name: "الكتالوج المشترك" });
  await expect(list.getByRole("row").nth(1)).toContainText("₪ 6.00 – ₪ 7.25");
  await expect(list.getByRole("row").nth(1)).toContainText("2 تبيعه الآن");
  await expect(list.getByRole("row").nth(2)).toContainText("₪ 2.00");
  await page.getByPlaceholder("اسم المنتج أو الباركود").fill("6291041500213");
  await expect.poll(() => lastQuery?.get("search")).toBe("6291041500213");

  await list.getByRole("link", { name: "حليب 1 لتر" }).click();
  await expect(page.getByRole("note")).toContainText("بفارق");
  await expect(page.getByRole("note")).toContainText("₪ 1.25");
  const offers = page.getByRole("table", { name: "المتاجر التي تبيع حليب 1 لتر" });
  await expect(offers.getByRole("row").nth(1)).toContainText("خان يونس");
  await expect(offers.getByRole("row").nth(1)).not.toContainText("الأقل");
  await expect(offers.getByRole("row").nth(2)).toContainText("الأقل");
  await expect(offers.getByRole("row").nth(3)).toContainText("الأعلى");
  await expect(offers.getByRole("row").nth(2)).toContainText("30");
});

test("support: the admin sees new complaints from every store, replies and closes one", async ({ page }) => {
  await signIn(page, admin);
  let ticket = {
    id: 3,
    type: "technical",
    subject: "الطابعة لا تطبع الإيصال",
    details: "بعد البيع تظهر رسالة خطأ.",
    status: "open",
    reply: null,
    replied_at: null,
    created_at: "2026-10-27T08:00:00Z",
    user: { id: 2, name: "علي أحمد", phone: "0599333444" },
    store: { id: 5, name: "بقالة الأمانة", phone: "0599123456" },
  };
  let answered = null;
  await page.route("**/api/v1/admin/support-tickets**", (r) =>
    r.fulfill({ json: { data: [ticket], meta: { current_page: 1, last_page: 1, total: 1, open_count: ticket.status === "open" ? 1 : 0 } } }),
  );
  await page.route("**/api/v1/admin/support-tickets/3", async (r) => {
    answered = r.request().postDataJSON();
    ticket = { ...ticket, ...answered, replied_at: "2026-10-27T09:00:00Z" };
    await r.fulfill({ json: { data: ticket } });
  });

  await page.goto("/admin/support");
  await expect(page.getByRole("link", { name: /الدعم الفني/ })).toContainText("1");
  await expect(page.getByText("1 شكوى جديدة بانتظار الرد")).toBeVisible();
  await expect(page.getByRole("link", { name: "بقالة الأمانة" })).toBeVisible();

  await page.getByRole("button", { name: "الرد على الشكوى" }).click();
  const dialog = page.getByRole("dialog", { name: /الرد على/ });
  await dialog.getByLabel(/الرد/).fill("حدّث التطبيق ثم أعد المحاولة.");
  await dialog.getByRole("button", { name: "حفظ" }).click();
  await expect.poll(() => answered).toEqual({ status: "closed", reply: "حدّث التطبيق ثم أعد المحاولة." });
});
