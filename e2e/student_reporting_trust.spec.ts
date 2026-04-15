import { test, expect, type Page } from '@playwright/test';
import {
  activateControl,
  ensureDemoSignedIn,
  ensureFlutterSemantics,
  expectFeedbackMessage,
  gotoRoot,
} from './helpers';

async function gotoSignedInPath(page: Page, path: string) {
  await gotoRoot(page);
  await ensureDemoSignedIn(page);
  await page.goto(path);
  await ensureFlutterSemantics(page);
}

async function selectDropdownOption(
  page: Page,
  currentValue: RegExp,
  nextValue: RegExp,
) {
  await activateControl(page.getByRole('button', { name: currentValue }).first());
  await activateControl(page.getByRole('menuitem', { name: nextValue }).first());
}

test('Exam input: valid save persists into results and invalid score is rejected', async ({
  page,
}) => {
  test.setTimeout(240_000);

  await gotoSignedInPath(page, '/class/demo-class-1/exams');

  await expect(page.getByText('Final Exam Scores', { exact: true }).first()).toBeVisible({
    timeout: 60_000,
  });
  await expect(
    page.getByRole('button', { name: /^Import scores$/i }),
  ).toBeVisible();

  const scoreField = page.getByRole('textbox', { name: /^Exam score$/i }).first();
  await expect(scoreField).toBeVisible({ timeout: 60_000 });

  const originalValue = await scoreField.inputValue();
  const validValue = originalValue === '88' ? '89' : '88';

  await scoreField.fill(validValue);
  await scoreField.press('Enter');
  await expectFeedbackMessage(page, /Exam score updated/i);

  await scoreField.fill('101');
  await scoreField.press('Tab');
  await expectFeedbackMessage(
    page,
    /Invalid score \(must be 0-100\)\. Restored the previous value\./i,
  );

  await page.reload();
  await ensureFlutterSemantics(page);
  await page.goto('/class/demo-class-1/results');
  await ensureFlutterSemantics(page);
  await expect(page.locator('body')).toContainText(
    new RegExp(
      String.raw`ID demo-class-1-student-1 / Seat 1[\s\S]*Exam 60%[\s\S]*${validValue}\.0`,
      'i',
    ),
  );
});

test('Final results: weighted results surface loads with roster context', async ({
  page,
}) => {
  test.setTimeout(180_000);

  await gotoSignedInPath(page, '/class/demo-class-1/results');

  await expect(
    page.getByRole('group', {
      name: /Final Results.*Grade 10A.*Mathematics \/ 2024-2025 \/ Fall \/ 5 students/i,
    }),
  ).toBeVisible({ timeout: 60_000 });
  await expect(page.locator('body')).toContainText('Process 40%');
  await expect(page.locator('body')).toContainText('Exam 60%');
  await expect(page.locator('body')).toContainText('Final grade');
  await expect(page.locator('body')).toContainText('demo-class-1-student-1');
});

test('Student flows: roster search narrows results and detail view stays coherent', async ({
  page,
}) => {
  test.setTimeout(180_000);

  await gotoSignedInPath(page, '/class/demo-class-1/students');

  await expect(page.getByText('Students', { exact: true }).first()).toBeVisible({
    timeout: 60_000,
  });

  const searchBox = page.getByRole('textbox', {
    name: /Search by name, ID, seat, or class code/i,
  });
  await expect(searchBox).toBeVisible();
  await expect(page.locator('body')).toContainText('Grade 10A');
  await searchBox.fill('student-2');

  const filteredStudent = page.getByRole('group', {
    name: /F .*Fang Wang.*demo-class-1-student-2/i,
  });
  await expect(filteredStudent).toBeVisible();
  await expect(page.locator('body')).toContainText('1 shown');

  await page.goto('/class/demo-class-1/student/demo-class-1-student-2');
  await ensureFlutterSemantics(page);

  await expect(page).toHaveURL(/\/class\/demo-class-1\/student\/demo-class-1-student-2(?:\?|$)/);
  await expect(page.getByText('Grade breakdown', { exact: true }).first()).toBeVisible({
    timeout: 60_000,
  });
  await expect(page.locator('body')).toContainText('demo-class-1-student-2');
  await expect(page.locator('body')).toContainText('Process score (40%)');
  await expect(page.locator('body')).toContainText('Exam score (60%)');
  await expect(page.locator('body')).toContainText('Final grade');
});

test('Export: per-student scope previews the selected student report', async ({
  page,
}) => {
  test.setTimeout(180_000);

  await gotoSignedInPath(page, '/class/demo-class-1/export');

  await expect(page.getByText('Class export', { exact: true }).first()).toBeVisible({
    timeout: 60_000,
  });

  await selectDropdownOption(page, /^Per class$/i, /^Per student$/i);
  await expect(page.getByText('Student report', { exact: true }).first()).toBeVisible();
  await expect(page.locator('body')).toContainText('demo-class-1-student-1');

  await page.getByRole('button', { name: /^Preview CSV$/i }).click();
  await expect(page.getByText('Student CSV Preview', { exact: true }).first()).toBeVisible({
    timeout: 90_000,
  });
  await expect(page.locator('body')).toContainText('demo-class-1-student-1');
});

test('Export: all-classes scope keeps trust messaging visible and previews combined CSV', async ({
  page,
}) => {
  test.setTimeout(180_000);

  await gotoSignedInPath(page, '/class/demo-class-1/export');

  await selectDropdownOption(page, /^Per class$/i, /^All classes$/i);

  await expect(page.locator('body')).toContainText('All-classes logic', {
    timeout: 60_000,
  });
  await expect(page.locator('body')).toContainText(
    'repository snapshots per class',
  );

  await page.getByRole('button', { name: /^Preview CSV$/i }).click();
  await expect(
    page.getByRole('button', { name: /^Download CSV$/i }),
  ).toBeVisible({ timeout: 90_000 });
});
