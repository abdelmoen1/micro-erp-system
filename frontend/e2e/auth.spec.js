import { expect, test } from "@playwright/test";

// D-32 proof: login, plus the DEF-13 regression (TC-0201-02). The API is mocked with the real
// response shapes of POST /login and POST /register (docs/api/auth.http).

const user = { id: 2, name: "Abu Ahmad", email: "owner@example.com", role: "owner", store_id: 1 };

test("owner logs in and lands on the dashboard with a stored session", async ({ page }) => {
  let sent;
  await page.route("**/api/v1/login", async (route) => {
    sent = route.request().postDataJSON();
    await route.fulfill({ status: 200, json: { message: "تم تسجيل دخولك بنجاح", user, token: "2|test-token" } });
  });

  await page.goto("/login");
  await page.getByPlaceholder("Email Address").fill("owner@example.com");
  await page.getByPlaceholder("Password").fill("password123");
  await page.getByRole("button", { name: "Log In" }).click();

  await expect(page).toHaveURL(/\/dashboard$/);
  expect(sent).toEqual({ email: "owner@example.com", password: "password123" });
  expect(await page.evaluate(() => localStorage.getItem("token"))).toBe("2|test-token");
});

test("DEF-13: the register form creates the store through the API", async ({ page }) => {
  let sent;
  await page.route("**/api/v1/register", async (route) => {
    sent = route.request().postDataJSON();
    await route.fulfill({ status: 201, json: { message: "تم إنشاء المتجر والمالك بنجاح", user, token: "3|new-owner" } });
  });

  await page.goto("/register");
  await fillRegistration(page);
  await page.getByRole("button", { name: "Sign Up" }).click();

  await expect(page).toHaveURL(/\/dashboard$/);
  expect(sent).toEqual({
    store_name: "Al-Amal Grocery",
    owner_name: "Abu Ahmad",
    email: "owner@example.com",
    password: "password123",
    password_confirmation: "password123",
  });
  expect(await page.evaluate(() => localStorage.getItem("token"))).toBe("3|new-owner");
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

  await page.goto("/register");
  await fillRegistration(page);
  await page.getByRole("button", { name: "Sign Up" }).click();

  await expect(page.getByText("The email has already been taken.")).toBeVisible();
  await expect(page).toHaveURL(/\/register$/);
  expect(await page.evaluate(() => localStorage.getItem("token"))).toBeNull();
});

async function fillRegistration(page) {
  await page.getByPlaceholder("Store Name").fill("Al-Amal Grocery");
  await page.getByPlaceholder("Owner Name").fill("Abu Ahmad");
  await page.getByPlaceholder("Email Address").fill("owner@example.com");
  await page.getByPlaceholder("Password", { exact: true }).fill("password123");
  await page.getByPlaceholder("Confirm Password").fill("password123");
  await page.locator("#remember").check();
}
