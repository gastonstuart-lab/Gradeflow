import { test, expect, type Page } from '@playwright/test';

async function ensureFlutterSemantics(page: Page) {
  const enable = page.locator('button[aria-label="Enable accessibility"]');
  if ((await enable.count()) > 0) {
    await enable.first().click({ timeout: 10_000 });
    await page.waitForSelector('flt-semantics-host', { timeout: 20_000 });
  }
}

async function ensureDemoSignedIn(page: Page) {
  await ensureFlutterSemantics(page);

  if (/\/dashboard(\b|\/|\?|#)/.test(page.url())) return;

  const demo = page.getByRole('button', { name: 'Try Demo Account' });
  await demo.first().waitFor({ timeout: 30_000 });
  await demo.first().click();
  await expect(page).toHaveURL(/\/dashboard/);
}

function escapeRegex(value: string) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

test('Seating: toolbar actions and room setup save flow work', async ({ page }) => {
  test.setTimeout(180_000);

  const layoutName = `Layout ${Date.now()}`;
  const roomName = `Room ${Date.now()}`;

  await page.goto('/');
  await ensureDemoSignedIn(page);

  await page.goto('/#/class/demo-class-1/seating');
  await ensureFlutterSemantics(page);

  await expect(page.getByRole('heading', { name: /Grade 10A Seating/i })).toBeVisible({
    timeout: 60_000,
  });

  await page.getByRole('button', { name: /^New layout$/i }).click();
  await expect(page.getByText('New layout')).toBeVisible();
  await page.getByRole('textbox').last().fill(layoutName);
  await page.getByRole('button', { name: /^Create$/i }).click();
  await expect(
    page.getByRole('button', {
      name: new RegExp(`Active Layout ${escapeRegex(layoutName)}`),
    }),
  ).toBeVisible();

  await page.getByRole('button', { name: /^Duplicate$/i }).click();
  await expect(
    page.getByRole('button', {
      name: new RegExp(`Active Layout ${escapeRegex(`${layoutName} copy`)}`),
    }),
  ).toBeVisible();

  const editRoom = page.getByRole('checkbox', { name: /^Edit room$/i });
  await editRoom.click();
  await expect(page.getByText(/Edit room is on\./i)).toBeVisible();

  await page.getByRole('button', { name: /^Show menu Add furniture$/i }).click();
  await page.getByRole('menuitem', { name: /^Desk$/i }).click();
  await expect(page.getByRole('button', { name: 'Edit table' }).first()).toBeVisible();

  await page.getByRole('button', { name: /^Room setups$/i }).click();
  await expect(page.getByText('Room setups', { exact: true })).toBeVisible();

  await page.getByRole('button', { name: /^Save current room$/i }).click();
  await expect(page.getByText('Save room setup')).toBeVisible();
  await page.getByRole('textbox', { name: /^Room name$/i }).fill(roomName);
  await page.getByRole('button', { name: /^Save room$/i }).click();

  await expect(
    page.getByRole('group', {
      name: new RegExp(`${escapeRegex(roomName)}.*Linked here`),
    }),
  ).toBeVisible();
  await page.getByRole('button', { name: /^Dismiss$/i }).click();
  await expect(
    page.getByRole('button', {
      name: new RegExp(`Using room: ${escapeRegex(roomName)}`),
    }),
  ).toBeVisible();
});
