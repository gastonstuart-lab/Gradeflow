import { defineConfig, devices } from '@playwright/test';

const port = process.env.PORT ?? '7357';
const baseURL = process.env.BASE_URL ?? `http://127.0.0.1:${port}`;

export default defineConfig({
  testDir: './e2e',
  timeout: 60_000,
  expect: { timeout: 10_000 },
  fullyParallel: true,
  retries: process.env.CI ? 2 : 0,
  reporter: [['html', { open: 'never' }], ['list']],
  webServer: {
    command:
      process.env.E2E_WEB_SERVER_COMMAND ??
      `powershell -NoProfile -Command "flutter build web --release; npx serve build/web -s -l ${port}"`,
    url: baseURL,
    reuseExistingServer: !process.env.CI,
    timeout: 180_000,
  },
  use: {
    baseURL,
    trace: 'on-first-retry',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
