import { defineConfig, devices } from "@playwright/test";

// D-32 Playwright proof (S2). The browser runs the real React app on the Vite dev server; the
// Laravel API is replaced per test with page.route() so CI needs no backend or database.
const PORT = 4179;

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [["list"], ["html", { open: "never" }]] : "list",
  use: {
    baseURL: `http://127.0.0.1:${PORT}`,
    trace: "on-first-retry",
  },
  // CI uses Playwright's bundled Chromium. Locally, PW_CHANNEL=chrome (or msedge) reuses an
  // installed browser instead of downloading one.
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"], channel: process.env.PW_CHANNEL || undefined } }],
  webServer: {
    command: `npx vite --host 127.0.0.1 --port ${PORT} --strictPort`,
    url: `http://127.0.0.1:${PORT}`,
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
