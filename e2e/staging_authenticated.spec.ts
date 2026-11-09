import { test, expect } from '@playwright/test';
import { ensureFlutterSemantics } from './helpers';

test('@staging authenticated GradeFlow routes to V2 Classroom on local emulators',
    async ({ page }) => {
  test.setTimeout(180_000);
  const browserDiagnostics: string[] = [];
  page.on('console', (message) => {
    if (message.type() === 'error' || message.type() === 'warning') {
      browserDiagnostics.push(message.type() + ': ' + message.text());
    }
  });
  page.on('pageerror', (error) => browserDiagnostics.push('page: ' + error.message));
  page.on('response', (response) => {
    if (response.url().includes('identitytoolkit') ||
        response.url().includes('securetoken')) {
      browserDiagnostics.push('auth-http: ' + response.status() + ' ' +
        new URL(response.url()).pathname);
    }
  });
  await page.goto('/');
  await ensureFlutterSemantics(page);

  await expect(page.getByText('Staging safety check')).toHaveCount(0);
  const email = page.getByRole('textbox', { name: 'Email' }).first();
  const password = page.getByRole('textbox', { name: 'Password' }).first();
  await expect(email).toBeVisible({ timeout: 30_000 });
  await email.fill('browser-teacher@example.invalid');
  await password.fill('FakePassword-Teacher123!');
  await page.getByRole('button', { name: /^Sign in$/i }).first().click();
  try {
    await expect.poll(() => new URL(page.url()).pathname, { timeout: 15_000 }).toBe('/os/home');
  } catch (error) {
    console.log('Authentication failure diagnostics:', browserDiagnostics);
    console.log('Visible browser text:',
      (await page.locator('body').innerText().catch(() => '')).slice(0, 2500));
    throw error;
  }

  await page.goto('/os/class/class-science-browser');
  await ensureFlutterSemantics(page);
  try {
    await expect(page.getByText('Synthetic Science 2B').first())
      .toBeVisible({ timeout: 15_000 });
  } catch (error) {
    console.log('Class workspace URL:', page.url());
    console.log('Class workspace diagnostics:', browserDiagnostics);
    console.log('Class workspace visible text:',
      (await page.locator('body').innerText().catch(() => '')).slice(0, 3500));
    throw error;
  }

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
