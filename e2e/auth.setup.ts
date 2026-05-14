import { test as setup, expect } from '@playwright/test';
import {
  ensureDemoSignedIn,
  ensureFlutterSemantics,
  expectDashboardShell,
} from './helpers';

const authFile = 'test-results/.auth/demo-user.json';

setup('authenticate demo workspace', async ({ page }) => {
  setup.setTimeout(240_000);

  await page.goto('/');
  await ensureFlutterSemantics(page);
  await ensureDemoSignedIn(page);
  await expect(page).toHaveURL(/(?:\/|\/#\/)(?:dashboard|os\/home)(?:[?#]|$)/);
  await expectDashboardShell(page);
  await page.context().storageState({ path: authFile });
});
