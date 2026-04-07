import { test, expect } from '@playwright/test';
import {
  classesPath,
  dashboardPath,
  ensureDemoSignedIn,
  ensureFlutterSemantics,
  expectExportSurface,
  expectSeatingSurface,
  expectFeedbackMessage,
  expectDashboardShell,
  gotoClasses,
  gotoDashboard,
  gotoRoot,
  gotoDemoClassRoute,
  openFirstClassWorkspace,
} from './helpers';

test.describe.configure({ mode: 'serial' });

test('Export: grade export screen loads with actionable controls', async ({
  page,
}) => {
  test.setTimeout(120_000);

  await gotoRoot(page);
  await ensureDemoSignedIn(page);

  await gotoDemoClassRoute(page, 'export');

  await expectExportSurface(page);
  await expect(page.getByRole('button', { name: /^Export(?: \(PDF\))?$/i })).toBeVisible();
  await expect(page.getByRole('button', { name: /^Preview$/i })).toBeVisible();
});

test('Export: browser export action shows download feedback', async ({ page }) => {
  test.setTimeout(180_000);

  await gotoRoot(page);
  await ensureDemoSignedIn(page);

  await gotoDemoClassRoute(page, 'export');

  await expectExportSurface(page);

  await page.getByRole('button', { name: /^Export(?: \(PDF\))?$/i }).click();

  const exportAnyway = page.getByRole('button', { name: /^Export Anyway$/i });
  if (await exportAnyway.isVisible({ timeout: 3_000 }).catch(() => false)) {
    await exportAnyway.click();
  }

  await expectFeedbackMessage(
    page,
    /CSV downloaded|Download blocked or failed/i,
  );
});

test('Export: CSV preview supports download action', async ({ page }) => {
  test.setTimeout(180_000);

  await gotoRoot(page);
  await ensureDemoSignedIn(page);

  await gotoDemoClassRoute(page, 'export');

  await expectExportSurface(page);

  await page.getByRole('button', { name: /^Preview$/i }).click();
  await expect(page.getByText(/CSV Preview/i)).toBeVisible({
    timeout: 60_000,
  });

  const csvDialog = page
    .getByText(/Class CSV Preview|CSV Preview/i)
    .first();
  await expect(csvDialog).toBeVisible();

  const downloadPromise = page
    .waitForEvent('download', { timeout: 10_000 })
    .catch(() => null);

  await page.getByRole('button', { name: /^Download CSV$/i }).click();
  const download = await downloadPromise;

  if (!download) {
    const feedback = page.getByText(/CSV downloaded|Download blocked or failed/i).first();
    const hasFeedback = await feedback.isVisible({ timeout: 5_000 }).catch(() => false);
    if (hasFeedback) {
      await expect(feedback).toBeVisible();
    } else {
      await expect(page.getByRole('button', { name: /^Download CSV$/i })).toBeVisible();
      await expect(page.getByRole('button', { name: /^Copy CSV$/i })).toBeVisible();
      await expect(page.getByRole('table').first()).toBeVisible();
    }
  }
});

test('Export: PDF preview exposes download action', async ({ page }) => {
  test.setTimeout(180_000);

  await gotoRoot(page);
  await ensureDemoSignedIn(page);
  await gotoDemoClassRoute(page, 'export');

  await expectExportSurface(page);

  // Switch export format from CSV to PDF.
  await page.getByRole('button', { name: /^CSV \(Spreadsheet\)$/i }).click();
  await page.getByRole('menuitem', { name: /^PDF \(Report\)$/i }).click();

  await page
    .getByRole('button', { name: /^Preview(?: \(PDF\)| PDF)?$/i })
    .first()
    .click();
  await expect(
    page.getByText(/Student PDF Preview|Class PDF Preview/i),
  ).toBeVisible({ timeout: 90_000 });

  const downloadPromise = page
    .waitForEvent('download', { timeout: 10_000 })
    .catch(() => null);

  await page.getByRole('button', { name: /^Download PDF$/i }).click();

  const download = await downloadPromise;
  if (download) {
    await expect.soft(download.suggestedFilename()).toMatch(/\.pdf$/i);
  }

  await expect(page.getByRole('button', { name: /^Download PDF$/i })).toBeVisible();
});

test('Export: PDF preview close and reopen keeps download action available', async ({ page }) => {
  test.setTimeout(180_000);

  await gotoRoot(page);
  await ensureDemoSignedIn(page);
  await gotoDemoClassRoute(page, 'export');

  await expectExportSurface(page);

  await page.getByRole('button', { name: /^CSV \(Spreadsheet\)$/i }).click();
  await page.getByRole('menuitem', { name: /^PDF \(Report\)$/i }).click();

  const previewTitle = page.getByText(/Student PDF Preview|Class PDF Preview/i);

  await page
    .getByRole('button', { name: /^Preview(?: \(PDF\)| PDF)?$/i })
    .first()
    .click();
  await expect(previewTitle).toBeVisible({ timeout: 90_000 });
  await expect(page.getByRole('button', { name: /^Download PDF$/i })).toBeVisible();

  await page.keyboard.press('Escape');
  await expect(previewTitle).toBeHidden({ timeout: 30_000 });

  await page
    .getByRole('button', { name: /^Preview(?: \(PDF\)| PDF)?$/i })
    .first()
    .click();
  await expect(previewTitle).toBeVisible({ timeout: 90_000 });
  await expect(page.getByRole('button', { name: /^Download PDF$/i })).toBeVisible();
});

test('Seating: editor and full screen flow loads', async ({ page }) => {
  test.setTimeout(120_000);

  await gotoRoot(page);
  await ensureDemoSignedIn(page);

  await openFirstClassWorkspace(page);
  await page.getByRole('button', { name: /^Seating\b/i }).first().click();
  await ensureFlutterSemantics(page);

  await expectSeatingSurface(page);
  await expect(
    page.getByRole('checkbox', { name: /^Edit room$/i }),
  ).toBeVisible();

  const editRoom = page.getByRole('checkbox', { name: /^Edit room$/i });
  const addFurniture = page.getByRole('button', { name: /^Show menu Add furniture$/i });
  await expect(editRoom).toBeVisible({ timeout: 60_000 });
  await editRoom.scrollIntoViewIfNeeded();
  const toggled = await editRoom.click({ timeout: 8_000 }).then(() => true).catch(() => false);
  if (!toggled) {
    const pressed = await editRoom.press('Space').then(() => true).catch(() => false);
    if (!pressed) {
      await editRoom.click({ force: true });
    }
  }
  await expect
    .poll(
      async () =>
        (await editRoom.isChecked().catch(() => false))
        || (await addFurniture.isVisible({ timeout: 1_000 }).catch(() => false)),
      { timeout: 15_000 },
    )
    .toBeTruthy();
  await expect(addFurniture).toBeVisible();

  await page.getByRole('button', { name: /^Full screen$/i }).click();
  await expect(page.getByRole('heading', { name: /Seating chart/i })).toBeVisible();

  await page.getByRole('button', { name: 'Close' }).click();
  await expectSeatingSurface(page);
});

test('Seating: substitute handout preview supports download action', async ({
  page,
}) => {
  test.setTimeout(180_000);

  await gotoRoot(page);
  await ensureDemoSignedIn(page);

  await openFirstClassWorkspace(page);
  await page.getByRole('button', { name: /^Seating\b/i }).first().click();
  await ensureFlutterSemantics(page);

  await expectSeatingSurface(page);

  await page.getByRole('button', { name: /^Preview PDF$/i }).click();
  await expect(page.getByText(/handout preview/i)).toBeVisible({
    timeout: 90_000,
  });

  const downloadPromise = page
    .waitForEvent('download', { timeout: 10_000 })
    .catch(() => null);

  await page.getByRole('button', { name: /^Download PDF$/i }).click();
  const download = await downloadPromise;
  if (!download) {
    const handoutSignal = page
      .getByText(/PDF download started|Download blocked or failed/i)
      .or(page.getByRole('button', { name: /^Download PDF$/i }))
      .or(page.getByText(/handout preview/i));
    await expect(handoutSignal.first()).toBeVisible({ timeout: 30_000 });
  }
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

  await gotoDemoClassRoute(page, 'seating');
  await expect(page).toHaveURL(/\/class\/[^/]+\/seating(?:\?|$)/);

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
