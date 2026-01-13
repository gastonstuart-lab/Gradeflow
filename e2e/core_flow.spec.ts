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

async function openDemoClassGradebook(page: Page) {
  await page.goto('/#/classes');
  await ensureFlutterSemantics(page);
  await expect(page.getByRole('button', { name: /^Grade 10A\b/i })).toBeVisible({
    timeout: 60_000,
  });

  await page.getByRole('button', { name: /^Grade 10A\b/i }).first().click();
  await expect(page.getByRole('heading', { name: 'Grade 10A' })).toBeVisible();

  await page.getByRole('button', { name: /^Gradebook\b/i }).first().click();
  await expect(page.getByText('Gradebook')).toBeVisible();

  // Select a category and a specific grade item so we can edit a score.
  await page.getByRole('button', { name: 'Homework' }).first().click();
  await page.getByRole('button', { name: 'Homework 1' }).first().click();

  await expect(page.getByRole('button', { name: 'Quick grade' }).first()).toBeVisible({
    timeout: 60_000,
  });
}

async function goBack(page: Page) {
  const back = page.getByRole('button', { name: 'Back' });
  if ((await back.count()) > 0) return back.first().click();
  return page.goBack();
}

async function openQuickGradeForFirstStudent(page: Page) {
  await page.getByRole('button', { name: 'Quick grade' }).first().click();
  await expect(page.getByRole('slider').first()).toBeVisible();
}

async function setSliderToLeftEdge(page: Page, slider = page.getByRole('slider').first()) {
  await expect(slider).toBeVisible();
  await expect(slider).toBeEnabled();

  await slider.evaluate((el) => {
    const input = el as HTMLInputElement;
    input.value = input.min || '1';
    input.dispatchEvent(new Event('input', { bubbles: true }));
    input.dispatchEvent(new Event('change', { bubbles: true }));
  });
}

async function clickSliderToValue(page: Page, value: number) {
  const slider = page.getByRole('slider').first();
  await expect(slider).toBeVisible();
  await expect(slider).toBeEnabled();

  const box = await slider.boundingBox();
  if (!box) throw new Error('Slider not visible');

  const min = 1;
  const max = 100;
  const clamped = Math.min(max, Math.max(min, value));
  const fraction = (clamped - min) / (max - min);
  const x = box.x + Math.max(2, Math.min(box.width - 2, box.width * fraction));
  const y = box.y + box.height / 2;

  await page.mouse.click(x, y);
}

async function getQuickGradeScore(page: Page) {
  const group = page.getByRole('group', {
    name: /Ming Li ID: demo-class-1-student-1/i,
  });
  await group.first().waitFor({ timeout: 10_000 });
  const label = await group.first().evaluate((el) => {
    const v = el.getAttribute('aria-label');
    if (v && v.trim()) return v.trim();
    return (el.textContent ?? '').trim();
  });
  const m = label.match(/\b\d+\/\d+\s+(\d+)\s*$/);
  if (!m) throw new Error(`Could not parse score from dialog label: ${label}`);
  return Number(m[1]);
}

test('core loop: edit score persists; undo reverts', async ({ page }) => {
  test.setTimeout(240_000);

  await page.goto('/');
  await ensureDemoSignedIn(page);

  await openDemoClassGradebook(page);

  // Set a distinctive score value, then verify it persists and can be undone.
  const target = 73;

  await openQuickGradeForFirstStudent(page);
  const before = await getQuickGradeScore(page);
  await clickSliderToValue(page, target);
  await expect.poll(() => getQuickGradeScore(page)).not.toBe(before);
  const after = await getQuickGradeScore(page);
  await page.getByRole('button', { name: 'Done' }).click();

  // Go back to class detail, re-enter gradebook, and verify the score persisted.
  await goBack(page);
  await expect(page.getByRole('heading', { name: 'Grade 10A' })).toBeVisible();
  await page.getByRole('button', { name: /^Gradebook\b/i }).first().click();
  await expect(page.getByText('Gradebook')).toBeVisible();
  await page.getByRole('button', { name: 'Homework' }).first().click();
  await page.getByRole('button', { name: 'Homework 1' }).first().click();
  await openQuickGradeForFirstStudent(page);
  await expect.poll(() => getQuickGradeScore(page)).toBe(after);
  await page.getByRole('button', { name: 'Done' }).click();

  // Undo the last score change.
  await page.getByRole('button', { name: 'Undo last score change' }).click();
  await expect(
    page.locator('flt-announcement-polite').getByText('Undid last score change'),
  ).toBeVisible();

  // Verify the score reverted back to what it was before the change.
  await openQuickGradeForFirstStudent(page);
  await expect.poll(() => getQuickGradeScore(page)).toBe(before);
  await page.getByRole('button', { name: 'Done' }).click();

  // Go back and re-enter again to ensure undo persisted.
  await goBack(page);
  await expect(page.getByRole('heading', { name: 'Grade 10A' })).toBeVisible();
  await page.getByRole('button', { name: /^Gradebook\b/i }).first().click();
  await expect(page.getByText('Gradebook')).toBeVisible();
  await page.getByRole('button', { name: 'Homework' }).first().click();
  await page.getByRole('button', { name: 'Homework 1' }).first().click();
  await openQuickGradeForFirstStudent(page);
  await expect.poll(() => getQuickGradeScore(page)).toBe(before);
});
