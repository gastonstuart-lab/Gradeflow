import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  testMatch: 'staging_authenticated.spec.ts',
  timeout: 180_000,
  expect: { timeout: 30_000 },
  retries: 0,
  workers: 1,
  reporter: [['list'], ['html', { open: 'never' }]],
  webServer: {
    command: 'npx serve build/web -s -l 7357',
    url: 'http://127.0.0.1:7357',
    reuseExistingServer: false,
    timeout: 90_000,
  },
  use: {
    baseURL: 'http://127.0.0.1:7357',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [{
    name: 'chromium',
    use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 900 } },
  }],
});
