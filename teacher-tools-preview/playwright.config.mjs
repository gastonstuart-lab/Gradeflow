import { defineConfig } from '@playwright/test';
export default defineConfig({
  testDir: './tests', timeout: 90000, expect: { timeout: 20000 },
  workers: 1, retries: 0, maxFailures: 2, reporter: [['list'], ['html', { open: 'never' }]],
  webServer: { command: 'npm run preview', url: 'http://127.0.0.1:4173', reuseExistingServer: false },
  use: { baseURL: 'http://127.0.0.1:4173', acceptDownloads: true, trace: 'retain-on-failure', screenshot: 'only-on-failure' },
  projects: [
    { name: 'surface-light', use: { browserName: 'chromium', viewport: { width: 1280, height: 900 }, hasTouch: true } },
    { name: 'surface-dark', use: { browserName: 'chromium', viewport: { width: 1280, height: 900 }, hasTouch: true } },
    { name: 'desktop-light', use: { browserName: 'chromium', viewport: { width: 1440, height: 1000 } } },
    { name: 'desktop-dark', use: { browserName: 'chromium', viewport: { width: 1440, height: 1000 } } },
  ],
});
