import { test, expect } from '@playwright/test';
import { ensureFlutterSemantics } from './helpers';

test('@staging authenticated GradeFlow routes to V2 Classroom on local emulators',
    async ({ page }) => {
  test.setTimeout(180_000);
  await page.goto('/');
  await ensureFlutterSemantics(page);

  await expect(page.getByText('Staging safety check')).toHaveCount(0);
  const email = page.getByRole('textbox', { name: 'Email' }).first();
  const password = page.getByRole('textbox', { name: 'Password' }).first();
  await expect(email).toBeVisible({ timeout: 30_000 });
  await email.fill('browser-teacher@example.invalid');
  await password.fill('FakePassword-Teacher123!');
  await page.getByRole('button', { name: /^Sign in$/i }).first().click();
  await expect(page).toHaveURL(/\/os\/home/, { timeout: 45_000 });

  await page.goto('/os/class/class-science-browser');
  await ensureFlutterSemantics(page);
  await expect(page.getByText('Synthetic Science 2B').first())
    .toBeVisible({ timeout: 45_000 });

  await page.goto('/os/class/class-science-browser/classroom');
  await ensureFlutterSemantics(page);
  await expect(page.getByText('Fit to screen').first())
    .toBeVisible({ timeout: 45_000 });
  await expect(page.getByText('Present').first()).toBeVisible();

  // Returning from Classroom to Home retains authorization and class
  // context; the browser connects only to localhost demo Firebase emulators.
  await page.goto('/os/home');
  await ensureFlutterSemantics(page);
  await expect(page.getByText('Staging safety check')).toHaveCount(0);
  await page.reload();
  await ensureFlutterSemantics(page);
  await expect(page.getByText('Staging safety check')).toHaveCount(0);
});
