import { test, expect, type Page } from '@playwright/test';

async function ensureFlutterSemantics(page: Page) {
  const enable = page.locator('button[aria-label="Enable accessibility"]');
  if ((await enable.count()) > 0) {
    await enable.first().click({ timeout: 10_000 });
    await page.waitForSelector('flt-semantics-host', { timeout: 20_000 });
  }
}

test('login screen loads', async ({ page }) => {
  await page.goto('/');

  await ensureFlutterSemantics(page);

  await expect(
    page.getByText('Professional Class Management for Teachers'),
  ).toBeVisible();

  await expect(page.getByLabel('Email')).toBeVisible();
  await expect(page.getByLabel('Password')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Sign In' })).toBeVisible();
  await expect(
    page.getByRole('button', { name: 'Continue with Google' }),
  ).toBeVisible();
  await expect(
    page.getByRole('button', { name: 'Try Demo Account' }),
  ).toBeVisible();
});

test('demo login navigates to dashboard', async ({ page }) => {
  test.setTimeout(120_000);
  await page.goto('/');

  await ensureFlutterSemantics(page);

  await page.getByRole('button', { name: 'Try Demo Account' }).click();

  // App uses GoRouter; dashboard is routed to /dashboard.
  await expect(page).toHaveURL(/\/dashboard/);

  // Sanity: dashboard contains at least one of these common labels.
  await expect(
    page.getByText(/Dashboard|Teacher Dashboard|Classes|Class/i).first(),
  ).toBeVisible();
});
