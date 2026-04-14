import { test, expect, type Page } from '@playwright/test';
import {
  activateControl,
  ensureDemoSignedIn,
  ensureFlutterSemantics,
  escapeRegex,
  gotoRoot,
} from './helpers';

test.describe.configure({ mode: 'serial' });

const dashboardSelectedClassStorageKey =
  'flutter.dashboard_selected_class_v1:demo-teacher-1';

async function signInToDemo(page: Page) {
  await gotoRoot(page);
  await ensureDemoSignedIn(page);
}

async function clearStoredDashboardSelection(page: Page) {
  await page.goto('/#/os/home');
  await ensureFlutterSemantics(page);
  await page.evaluate((key) => {
    window.localStorage.removeItem(key);
  }, dashboardSelectedClassStorageKey);
}

async function openDashboard(page: Page) {
  const gradebookButton = page.getByRole('button', { name: /^Gradebook\b/i }).first();

  await page.goto('/#/dashboard');
  await ensureFlutterSemantics(page);
  const dashboardReady = await gradebookButton.isVisible({ timeout: 8_000 })
    .catch(() => false);
  if (!dashboardReady) {
    await page.goto('/#/os/home');
    await ensureFlutterSemantics(page);
    await page.goto('/#/dashboard');
    await ensureFlutterSemantics(page);
  }

  await expect(gradebookButton).toBeVisible({ timeout: 60_000 });
  await expect(page.locator('body')).toContainText('Command deck');
}

async function selectDashboardClass(page: Page, className: string) {
  const classCard = page.getByRole('group', {
    name: new RegExp(`^${escapeRegex(className)}(?:\\b|\\n)`, 'i'),
  }).first();
  await expect(classCard).toBeVisible({ timeout: 60_000 });
  await activateControl(classCard);
  await expect(
    page.getByRole('button', {
      name: new RegExp(
        `^Seating Plan Open seating for ${escapeRegex(className)}\\.$`,
        'i',
      ),
    }).first(),
  ).toBeVisible({ timeout: 20_000 });
}

async function openDashboardClassroomTools(page: Page) {
  const classroomTab = page.getByRole('button', { name: /^Classroom$/i }).first();
  await expect(classroomTab).toBeVisible({ timeout: 30_000 });
  await activateControl(classroomTab);
  await expect(page.getByRole('button', { name: /^Class /i }).first())
    .toBeVisible({ timeout: 30_000 });
}

async function selectClassToolsClass(page: Page, className: string) {
  const picker = page.getByRole('button', { name: /^Class /i }).first();
  await activateControl(picker);
  const option = page.getByRole('menuitem', {
    name: new RegExp(`^${escapeRegex(className)}$`, 'i'),
  }).first();
  await expect(option).toBeVisible({ timeout: 15_000 });
  await activateControl(option);
  await expect(
    page.getByRole('button', {
      name: new RegExp(`^Class ${escapeRegex(className)}$`, 'i'),
    }).first(),
  ).toBeVisible({ timeout: 15_000 });
}

test('Fresh dashboard blocks class-target actions until a class is explicitly chosen', async ({
  page,
}) => {
  test.setTimeout(180_000);

  await signInToDemo(page);
  await clearStoredDashboardSelection(page);
  await openDashboard(page);

  const genericSeatingAction = page.getByRole('button', {
    name: /^Seating Plan Open seating for your class\.$/i,
  }).first();
  await expect(genericSeatingAction).toBeVisible({ timeout: 20_000 });

  await activateControl(page.getByRole('button', { name: /^Gradebook\b/i }).first());

  const body = page.locator('body');
  await expect(body).toContainText('Command deck');
  await expect(body).not.toContainText('Quick grade');
  await expect(body).not.toContainText('Back to classes');
  await expect(genericSeatingAction).toBeVisible();
});

test('Explicit dashboard class selection persists across refresh', async ({
  page,
}) => {
  test.setTimeout(180_000);

  await signInToDemo(page);
  await clearStoredDashboardSelection(page);
  await openDashboard(page);
  await selectDashboardClass(page, 'Grade 11B');

  await page.reload();
  await ensureFlutterSemantics(page);
  await expect(
    page.getByRole('button', {
      name: /^Seating Plan Open seating for Grade 11B\.$/i,
    }).first(),
  ).toBeVisible({ timeout: 60_000 });
});

test('Gradebook and Seating still open for the selected dashboard class', async ({
  page,
}) => {
  test.setTimeout(240_000);

  await signInToDemo(page);

  await openDashboard(page);
  await selectDashboardClass(page, 'Grade 11B');
  await activateControl(page.getByRole('button', { name: /^Gradebook\b/i }).first());
  await expect(page.locator('body')).toContainText('Grade 11B');
  await expect(page.locator('body')).toContainText('Quick grade');

  await openDashboard(page);
  await selectDashboardClass(page, 'Grade 11B');
  await activateControl(page.getByRole('button', { name: /^Seating\b/i }).first());
  await expect(page.locator('body')).toContainText('Grade 11B');
  await expect(page.locator('body')).toContainText('Layouts: 1');
});

test('Export and Final Exam show the selected class clearly in-screen', async ({
  page,
}) => {
  test.setTimeout(240_000);

  await signInToDemo(page);

  await openDashboard(page);
  await selectDashboardClass(page, 'Grade 11B');
  await activateControl(page.getByRole('button', { name: /^Reports\b/i }).first());
  await expect(page.locator('body')).toContainText('Grade 11B');
  await expect(page.locator('body')).toContainText('English');
  await expect(page.locator('body')).toContainText('Export Grades');

  await openDashboard(page);
  await selectDashboardClass(page, 'Grade 11B');
  await activateControl(page.getByRole('button', { name: /^Create Test\b/i }).first());
  await expect(page.locator('body')).toContainText('Grade 11B');
  await expect(page.locator('body')).toContainText('English');
  await expect(page.locator('body')).toContainText('Final Exam = 60% of total grade');
});

test('Class-tools seating, OS class cold-load, and OS home rail stay correct', async ({
  page,
}) => {
  test.setTimeout(240_000);

  await signInToDemo(page);

  await openDashboard(page);
  await openDashboardClassroomTools(page);
  await selectClassToolsClass(page, 'Grade 12C');
  await activateControl(page.getByRole('button', { name: /^Open seating plan$/i }).first());
  await expect(page.locator('body')).toContainText('Grade 12C');
  await expect(page.locator('body')).toContainText('Physics');
  await expect(page.locator('body')).toContainText('Layouts: 1');

  await page.goto('/#/os/class/demo-class-2');
  await ensureFlutterSemantics(page);
  const osClassHeader = page.locator('[aria-label*="Grade 11B"]').first();
  await expect(osClassHeader).toBeVisible({ timeout: 30_000 });
  await expect(osClassHeader).toHaveAttribute(
    'aria-label',
    /English · 5 students/i,
  );

  await page.goto('/#/os/home');
  await ensureFlutterSemantics(page);
  await expect(page.getByRole('button', { name: /^Grade 10A Mathematics$/i }))
    .toBeVisible({ timeout: 30_000 });
  await expect(page.getByRole('button', { name: /^Grade 11B English$/i }))
    .toBeVisible();
  await expect(page.getByRole('button', { name: /^Grade 12C Physics$/i }))
    .toBeVisible();
});
