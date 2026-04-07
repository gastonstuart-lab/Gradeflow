import { test, expect } from '@playwright/test';
import {
  activateControl,
  ensureDemoSignedIn,
  expectSeatingSurface,
  escapeRegex,
  gotoDemoClassRoute,
  gotoRoot,
} from './helpers';

async function currentLayoutCount(page: import('@playwright/test').Page) {
  const text = await page.getByText(/Layouts\s+\d+/i).first().innerText();
  const match = text.match(/Layouts\s+(\d+)/i);
  return match ? Number(match[1]) : 0;
}

test('Seating: toolbar actions and room setup save flow work', async ({ page }) => {
  test.setTimeout(300_000);

  const layoutName = `Layout ${Date.now()}`;
  const roomName = `Room ${Date.now()}`;

  await gotoRoot(page);
  await ensureDemoSignedIn(page);

  await gotoDemoClassRoute(page, 'seating');
  await expectSeatingSurface(page);

  await page.getByRole('button', { name: /^New layout$/i }).click();
  await expect(page.getByText('New layout')).toBeVisible();
  await page.getByRole('textbox').last().fill(layoutName);
  await page.getByRole('button', { name: /^Create$/i }).click();
  await expect(
    page.getByRole('button', {
      name: new RegExp(`(?:Active )?Layout ${escapeRegex(layoutName)}`),
    }),
  ).toBeVisible();

  const beforeDuplicateCount = await currentLayoutCount(page);
  const activeLayoutBefore = await page
    .getByRole('button', { name: /^(?:Active )?Layout\b/i })
    .first()
    .innerText();

  const duplicateButton = page.getByRole('button', { name: /^Duplicate$/i });
  await duplicateButton.scrollIntoViewIfNeeded();
  const duplicated = await duplicateButton.press('Enter').then(() => true).catch(() => false);
  if (!duplicated) {
    const clicked = await duplicateButton.click({ timeout: 8_000 }).then(() => true).catch(() => false);
    if (!clicked) {
      await duplicateButton.click({ force: true });
    }
  }
  await expectSeatingSurface(page);

  await expect.poll(async () => {
    const nowCount = await currentLayoutCount(page);
    const activeLayoutNow = await page
      .getByRole('button', { name: /^(?:Active )?Layout\b/i })
      .first()
      .innerText();
    return nowCount > beforeDuplicateCount || activeLayoutNow !== activeLayoutBefore;
  }, { timeout: 30_000 }).toBeTruthy();

  await page.getByRole('button', { name: /^Room setups$/i }).click();
  await expect(page.getByText('Room setups', { exact: true })).toBeVisible();

  expect(page.isClosed()).toBe(false);
  await activateControl(page.getByRole('button', { name: /^Save current room$/i }).first());
  await expect(page.getByText('Save room setup')).toBeVisible();
  await page.getByRole('textbox', { name: /^Room name$/i }).fill(roomName);
  await activateControl(page.getByRole('button', { name: /^Save room$/i }).first());

  await expect(
    page.getByText(roomName, { exact: true }),
  ).toBeVisible();
  await expect(page.getByText('Linked here', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: /^Close$/i }).click();
  await expect(page.getByText(new RegExp(`Using room: ${escapeRegex(roomName)}`))).toBeVisible();
});
