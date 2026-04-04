import { test, expect } from '@playwright/test';
import {
  ensureDemoSignedIn,
  escapeRegex,
  gotoDemoClassRoute,
} from './helpers';

test('Seating: toolbar actions and room setup save flow work', async ({ page }) => {
  test.setTimeout(180_000);

  const layoutName = `Layout ${Date.now()}`;
  const roomName = `Room ${Date.now()}`;

  await page.goto('/');
  await ensureDemoSignedIn(page);

  await gotoDemoClassRoute(page, 'seating');

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
    page.getByText(roomName, { exact: true }),
  ).toBeVisible();
  await expect(page.getByText('Linked here', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: /^Close$/i }).click();
  await expect(page.getByText(new RegExp(`Using room: ${escapeRegex(roomName)}`))).toBeVisible();
});
