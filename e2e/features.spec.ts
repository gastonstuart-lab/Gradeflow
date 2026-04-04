import { test, expect } from '@playwright/test';
import {
  classesPath,
  dashboardPath,
  ensureDemoSignedIn,
  expectDashboardShell,
  gotoClasses,
  gotoDashboard,
  gotoDemoClassRoute,
} from './helpers';

test('Export: grade export screen loads with actionable controls', async ({
  page,
}) => {
  test.setTimeout(120_000);

  await page.goto('/');
  await ensureDemoSignedIn(page);

  await gotoDemoClassRoute(page, 'export');

  await expect(page.getByText('Export Options', { exact: true })).toBeVisible({
    timeout: 60_000,
  });
  await expect(page.getByRole('button', { name: /^Export(?: \(PDF\))?$/i })).toBeVisible();
  await expect(page.getByRole('button', { name: /^Preview$/i })).toBeVisible();
});

test('Seating: editor and full screen flow loads', async ({ page }) => {
  test.setTimeout(120_000);

  await page.goto('/');
  await ensureDemoSignedIn(page);

  await gotoDemoClassRoute(page, 'seating');

  await expect(page.getByRole('heading', { name: /Grade 10A Seating/i })).toBeVisible({
    timeout: 60_000,
  });
  await expect(
    page.getByRole('checkbox', { name: /^Edit room$/i }),
  ).toBeVisible();

  const editRoom = page.getByRole('checkbox', { name: /^Edit room$/i });
  await editRoom.click();
  await expect(page.getByText(/Edit room is on\./i)).toBeVisible();
  await expect(
    page.getByRole('button', { name: /^Show menu Add furniture$/i }),
  ).toBeVisible();

  await page.getByRole('button', { name: /^Show menu Add furniture$/i }).click();
  await page.getByRole('menuitem', { name: /^Desk$/i }).click();
  await expect(page.getByRole('button', { name: 'Edit table' })).toBeVisible();

  await page.getByRole('button', { name: /^Full screen$/i }).click();
  await expect(page.getByRole('heading', { name: /Seating chart/i })).toBeVisible();

  await page.getByRole('button', { name: 'Close' }).click();
  await expect(page.getByRole('heading', { name: /Grade 10A Seating/i })).toBeVisible();
});

test('Routing: direct navigation to classes works without refresh', async ({
  page,
}) => {
  test.setTimeout(120_000);

  await page.goto('/');
  await ensureDemoSignedIn(page);

  await gotoClasses(page);
  await expect(page).toHaveURL(new RegExp(`${classesPath.replace('/', '\\/')}(?:\\?|$)`));
});

test('Dashboard: utility dock keeps schedule reachable', async ({ page }) => {
  test.setTimeout(120_000);

  await page.goto('/');
  await ensureDemoSignedIn(page);

  await gotoDashboard(page);
  await expectDashboardShell(page);
  await expect(
    page.getByRole('button', { name: /^Schedule\b/i }).last(),
  ).toBeVisible();
});

test('Import: classes workspace opens source chooser', async ({ page }) => {
  test.setTimeout(120_000);

  await page.goto('/');
  await ensureDemoSignedIn(page);

  await gotoClasses(page);

  await page.getByRole('button', { name: /^Import$/i }).first().click();
  await expect(
    page.getByText('Import from Google Drive or local file', { exact: true }),
  ).toBeVisible();
  await expect(page.getByRole('button', { name: 'Local file' })).toBeVisible();
  await expect(
    page.getByRole('button', { name: 'From Google Drive link' }),
  ).toBeVisible();
  await expect(
    page.getByRole('button', { name: 'Browse Google Drive' }),
  ).toBeVisible();
});

test('Navigation: browser back returns from classes to dashboard', async ({
  page,
}) => {
  test.setTimeout(120_000);

  await page.goto('/');
  await ensureDemoSignedIn(page);

  await gotoDashboard(page);
  await page.goto(classesPath);
  await gotoClasses(page);

  await page.goBack();
  await expect(page).toHaveURL(new RegExp(`${dashboardPath.replace('/', '\\/')}(?:\\?|$)`));
  await expectDashboardShell(page);
});

test('Console: no critical errors during primary navigation', async ({ page }) => {
  test.setTimeout(120_000);

  const errors: string[] = [];

  page.on('console', (msg) => {
    if (msg.type() === 'error') {
      errors.push(msg.text());
    }
  });

  await page.goto('/');
  await ensureDemoSignedIn(page);

  await page.goto(classesPath);
  await gotoClasses(page);

  await page.goto('/class/demo-class-1/seating');
  await gotoDemoClassRoute(page, 'seating');

  await page.goto(dashboardPath);
  await gotoDashboard(page);

  const criticalErrors = errors.filter(
    (error) =>
      !error.includes('favicon') &&
      !error.includes('404') &&
      !error.includes('Failed to load'),
  );

  expect(criticalErrors).toHaveLength(0);
});
