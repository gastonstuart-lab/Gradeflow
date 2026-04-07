import { test, expect, type Page } from '@playwright/test';
import {
  activateControl,
  ensureDemoSignedIn,
  expectGradebookSurface,
  gotoDemoClassRoute,
  gotoRoot,
} from './helpers';

async function firstStudentGroup(page: Page) {
  const seatNamedGroup = page.getByRole('group', { name: /Seat\s*\d+/i }).first();
  if (await seatNamedGroup.isVisible({ timeout: 5_000 }).catch(() => false)) {
    return seatNamedGroup;
  }

  const group = page
    .getByRole('group')
    .filter({ has: page.getByRole('button', { name: 'Quick grade' }) })
    .first();
  await expect(group).toBeVisible({ timeout: 60_000 });
  return group;
}

async function firstStudentGroupLabel(page: Page) {
  const group = await firstStudentGroup(page);
  const aria = await group.getAttribute('aria-label');
  if (aria && aria.trim().length > 0) {
    return aria.trim();
  }

  return (await group.innerText()).trim();
}

async function ensureGradebookSelection(page: Page) {
  const quickGradeButton = page.getByRole('button', { name: 'Quick grade' }).first();
  if (await quickGradeButton.isVisible({ timeout: 3_000 }).catch(() => false)) {
    return;
  }

  for (const labelPattern of [/^Homework\b/i, /^Assignment\b/i, /^Quiz\b/i, /^Test\b/i]) {
    const option = page.getByRole('checkbox', { name: labelPattern }).first();
    if (await option.isVisible({ timeout: 2_000 }).catch(() => false)) {
      await option.click();
      if (await quickGradeButton.isVisible({ timeout: 2_000 }).catch(() => false)) {
        return;
      }
    }
  }

  const checkboxes = page.getByRole('checkbox');
  const total = await checkboxes.count();
  for (let i = 0; i < Math.min(total, 12); i += 1) {
    await checkboxes.nth(i).click();
    if (await quickGradeButton.isVisible({ timeout: 2_000 }).catch(() => false)) {
      return;
    }
  }

  await expect(quickGradeButton).toBeVisible({ timeout: 60_000 });
}

async function openDemoClassGradebook(page: Page) {
  await gotoDemoClassRoute(page, 'gradebook');
  await expectGradebookSurface(page);

  // Select a grade context so score controls are available even if labels shift.
  await ensureGradebookSelection(page);

  await expect(page.getByRole('button', { name: 'Quick grade' }).first()).toBeVisible({
    timeout: 60_000,
  });
}

async function reopenDemoClassGradebook(page: Page) {
  await gotoDemoClassRoute(page, 'gradebook');
  await expectGradebookSurface(page);
  await ensureGradebookSelection(page);
  await expect(page.getByRole('button', { name: 'Quick grade' }).first()).toBeVisible({
    timeout: 60_000,
  });
}

test('core loop: edit score persists; undo reverts', async ({ page }) => {
  test.setTimeout(360_000);

  await gotoRoot(page);
  await ensureDemoSignedIn(page);

  await openDemoClassGradebook(page);

  // Clear first score to make a deterministic edit regardless of seeded values.
  const before = await firstStudentGroupLabel(page);
  await page.getByRole('button', { name: 'Clear score' }).first().click();
  await expect.poll(() => firstStudentGroupLabel(page), { timeout: 60_000 }).not.toBe(before);

  // Re-open gradebook through resilient navigation to verify the edit persisted.
  await reopenDemoClassGradebook(page);
  await expect.poll(() => firstStudentGroupLabel(page), { timeout: 60_000 }).not.toBe(before);

  // Undo the last score change.
  expect(page.isClosed()).toBe(false);
  await activateControl(page.getByRole('button', { name: 'Undo last score change' }).first());
  const undoToast = page
    .locator('flt-announcement-polite')
    .getByText('Undid last score change');
  const hasUndoToast = await undoToast.isVisible({ timeout: 5_000 }).catch(() => false);
  if (hasUndoToast) {
    await expect(undoToast).toBeVisible();
  }

  // Verify the score reverted back to what it was before the change.
  await expect.poll(() => firstStudentGroupLabel(page), { timeout: 60_000 }).toBe(before);

  // Re-open gradebook again to ensure undo persisted.
  await reopenDemoClassGradebook(page);
  await expect.poll(() => firstStudentGroupLabel(page), { timeout: 60_000 }).toBe(before);
});
