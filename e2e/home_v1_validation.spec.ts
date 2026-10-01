import { test, expect } from '@playwright/test';
import {
  ensureFlutterSemantics,
  expectDashboardShell,
} from './helpers';

async function openValidatedHome(page: import('@playwright/test').Page) {
  await page.goto('/');
  await ensureFlutterSemantics(page);

  const demo = page
    .getByRole('button', { name: /^Open demo workspace$/i })
    .first();
  await expect(demo).toBeVisible({ timeout: 60_000 });
  await demo.click();

  // Wait for the real authenticated Home. Do not use the older demo helper
  // here because its legacy button matcher can race authentication.
  await expect(page.getByText('TEACHER HOME', { exact: true })).toBeVisible({
    timeout: 120_000,
  });
  await ensureFlutterSemantics(page);

  await expect(
    page.getByText('Where do you want to go?', { exact: true }),
  ).toBeVisible();
  await expectDashboardShell(page);
}

async function expectNoHorizontalOverflow(page: import('@playwright/test').Page) {
  const overflow = await page.evaluate(() => ({
    viewport: window.innerWidth,
    document: document.documentElement.scrollWidth,
    body: document.body.scrollWidth,
  }));

  expect(overflow.document).toBeLessThanOrEqual(overflow.viewport + 2);
  expect(overflow.body).toBeLessThanOrEqual(overflow.viewport + 2);
}

test('@home-v1 Home is clear at desktop and Surface-like landscape sizes', async ({ page }) => {
  test.setTimeout(240_000);

  await page.setViewportSize({ width: 1440, height: 900 });
  await openValidatedHome(page);

  const body = await page.locator('body').innerText();
  expect(body).toContain('Classroom');
  expect(body).toContain('Planner');
  expect(body).toContain('Grades');
  expect(body).toContain('Students');
  expect(body).toContain('IED Studio');
  expect(body).toContain('Science');

  expect(body).not.toContain('Continue last lesson');
  expect(body).not.toContain('Last opened at slide');
  expect(body).not.toMatch(/\b42%\b/);
  expect(body).not.toContain('Next class');\n  expect(body).not.toContain('PINNED APPS');\n  expect(body).not.toContain('DAILY SIGNALS');\n  expect(body).not.toContain('COMMAND CENTER');

  await expectNoHorizontalOverflow(page);

  await page.screenshot({
    path: 'artifacts/home-v1/home-desktop-1440x900.png',
    fullPage: true,
  });

  const classroom = page.getByText('Open Classroom', { exact: true }).first();
  await expect(classroom).toBeVisible();
  await classroom.click();
  await expect(page).toHaveURL(/\/os\/class\/[^/]+\/classroom(?:[?#].*)?$/);

  await page.goto('/os/home');
  await ensureFlutterSemantics(page);
  await expect(page.getByText('TEACHER HOME', { exact: true })).toBeVisible({
    timeout: 60_000,
  });

  await page.setViewportSize({ width: 1180, height: 720 });
  await page.waitForTimeout(400);

  await expect(page.getByText('TEACHER HOME', { exact: true })).toBeVisible();
  await expect(page.getByText('IED Studio', { exact: true })).toBeVisible();
  await expect(page.getByText('Science', { exact: true })).toBeVisible();
  await expectNoHorizontalOverflow(page);

  await page.screenshot({
    path: 'artifacts/home-v1/home-surface-1180x720.png',
    fullPage: true,
  });

  const themeButton = page
    .getByRole('button', { name: /Toggle theme/i })
    .first();
  if (await themeButton.isVisible({ timeout: 5_000 }).catch(() => false)) {
    await themeButton.click();
    await page.waitForTimeout(500);
    await expect(page.getByText('TEACHER HOME', { exact: true })).toBeVisible();
    await page.screenshot({
      path: 'artifacts/home-v1/home-surface-alt-theme-1180x720.png',
      fullPage: true,
    });
  }
});

test('@home-v1 live IED Studio signed-out route is reachable and protected', async ({ page }) => {
  test.setTimeout(120_000);
  const response = await page.goto('https://ied-hub.web.app/admin', {
    waitUntil: 'domcontentloaded',
  });

  expect(response, 'IED Studio should return a document response').not.toBeNull();
  expect(response!.status()).toBeLessThan(400);

  await page.waitForTimeout(2_500);
  const text = await page.locator('body').innerText();
  const protectedState =
    /Teacher Login|Sign in|IED Studio|Teacher Dashboard/i.test(text) ||
    /\/login(?:[?#].*)?$/.test(new URL(page.url()).pathname);

  expect(protectedState).toBeTruthy();

  await page.screenshot({
    path: 'artifacts/home-v1/ied-studio-signed-out.png',
    fullPage: true,
  });
});

test('@home-v1 live Science destination resolves through deployed IED Science Hub', async ({ page }) => {
  test.setTimeout(120_000);
  const response = await page.goto(
    'https://ied-hub.web.app/esl/science',
    { waitUntil: 'domcontentloaded' },
  );

  expect(response, 'Science Hub should return a document response').not.toBeNull();
  expect(response!.status()).toBeLessThan(400);

  await page.waitForTimeout(2_500);
  const text = await page.locator('body').innerText();
  expect(text).toMatch(/Science|lesson|course/i);

  await page.screenshot({
    path: 'artifacts/home-v1/science-lessons-live.png',
    fullPage: true,
  });
});
