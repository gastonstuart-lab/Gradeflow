import { test, expect, type Page } from "@playwright/test";
import {
  activateControl,
  ensureDemoSignedIn,
  expectGradebookSurface,
  gotoDemoClassRoute,
  gotoRoot,
} from "./helpers";

async function firstStudentGroup(page: Page) {
  const seatNamedGroup = page
    .getByRole("group", { name: /Seat\s*\d+/i })
    .first();
  if (await seatNamedGroup.isVisible({ timeout: 5_000 }).catch(() => false)) {
    return seatNamedGroup;
  }

  const group = page
    .getByRole("group")
    .filter({ has: page.getByRole("button", { name: "Clear score" }) })
    .first();
  await expect(group).toBeVisible({ timeout: 60_000 });
  return group;
}

async function firstStudentGroupLabel(page: Page) {
  const group = await firstStudentGroup(page);
  const aria = await group.getAttribute("aria-label");
  if (aria && aria.trim().length > 0) {
    return aria.trim();
  }

  return (await group.innerText()).trim();
}

async function ensureGradebookSelection(page: Page) {
  const clearScoreButton = page
    .getByRole("button", { name: /^Clear score$/i })
    .first();
  const quickGradeButton = page
    .getByRole("button", { name: "Quick grade" })
    .first();
  if (await clearScoreButton.isVisible({ timeout: 3_000 }).catch(() => false)) {
    return;
  }

  await expect(clearScoreButton).toBeVisible({ timeout: 60_000 });
  await expect(quickGradeButton).toBeVisible({ timeout: 60_000 });
}

async function openDemoClassGradebook(page: Page) {
  await gotoDemoClassRoute(page, "gradebook");
  await expectGradebookSurface(page);

  // Select a grade context so score controls are available even if labels shift.
  await ensureGradebookSelection(page);

  await expect(
    page.getByRole("button", { name: "Quick grade" }).first(),
  ).toBeVisible({
    timeout: 60_000,
  });
  await expect(
    page.getByRole("button", { name: "Clear score" }).first(),
  ).toBeVisible({
    timeout: 60_000,
  });
}

async function reopenDemoClassGradebook(page: Page) {
  const backToClasses = page
    .getByRole("button", { name: /^Back to classes$/i })
    .first();
  if (await backToClasses.isVisible({ timeout: 5_000 }).catch(() => false)) {
    await activateControl(backToClasses);
  }

  const openClass = page.getByRole("button", { name: /^Open class$/i }).first();
  await expect(openClass).toBeVisible({ timeout: 60_000 });
  await activateControl(openClass);

  const gradebookLauncher = page
    .getByRole("button", { name: /^Gradebook\b/i })
    .first();
  await expect(gradebookLauncher).toBeVisible({ timeout: 60_000 });
  await activateControl(gradebookLauncher);

  await expectGradebookSurface(page);
  await ensureGradebookSelection(page);
  await expect(
    page.getByRole("button", { name: "Quick grade" }).first(),
  ).toBeVisible({
    timeout: 60_000,
  });
  await expect(
    page.getByRole("button", { name: "Clear score" }).first(),
  ).toBeVisible({
    timeout: 60_000,
  });
}

test("core loop: edit score persists; undo reverts", async ({ page }) => {
  test.setTimeout(360_000);

  await gotoRoot(page);
  await ensureDemoSignedIn(page);

  await openDemoClassGradebook(page);

  // Clear first score to make a deterministic edit regardless of seeded values.
  const before = await firstStudentGroupLabel(page);
  await page.getByRole("button", { name: "Clear score" }).first().click();
  await expect
    .poll(() => firstStudentGroupLabel(page), { timeout: 60_000 })
    .not.toBe(before);

  // Re-open gradebook through resilient navigation to verify the edit persisted.
  await reopenDemoClassGradebook(page);
  await expect
    .poll(() => firstStudentGroupLabel(page), { timeout: 60_000 })
    .not.toBe(before);

  // Undo the last score change.
  expect(page.isClosed()).toBe(false);
  await activateControl(
    page.getByRole("button", { name: /^Undo last (score )?change$/i }).first(),
  );

  // Verify the score reverted back to what it was before the change.
  await expect
    .poll(() => firstStudentGroupLabel(page), { timeout: 60_000 })
    .toBe(before);

  // Re-open gradebook again to ensure undo persisted.
  await reopenDemoClassGradebook(page);
  await expect
    .poll(() => firstStudentGroupLabel(page), { timeout: 60_000 })
    .toBe(before);
});
