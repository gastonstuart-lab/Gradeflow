import { expect, type Page } from '@playwright/test';

export const dashboardPath = '/dashboard';
export const classesPath = '/classes';
export const demoClassId = 'demo-class-1';

export async function ensureFlutterSemantics(page: Page) {
  const enable = page.locator('button[aria-label="Enable accessibility"]');
  if ((await enable.count()) > 0) {
    await enable.first().click({ timeout: 10_000 });
    await page.waitForSelector('flt-semantics-host', { timeout: 20_000 });
  }
}

export async function ensureDemoSignedIn(page: Page) {
  await ensureFlutterSemantics(page);

  if (/\/dashboard(?:\b|\/|\?|#|$)/.test(page.url())) {
    return;
  }

  const demo = page.getByRole('button', { name: 'Try Demo Account' });
  await demo.first().waitFor({ timeout: 60_000 });
  await demo.first().click();
  await expect(page).toHaveURL(/\/dashboard(?:\?|$)/);
}

export async function expectDashboardShell(page: Page) {
  const attentionButton = page.getByRole('button', {
    name: 'Attention center',
  });
  await expect(attentionButton).toBeVisible({ timeout: 60_000 });

  for (const label of ['Classes', 'Studio', 'Schedule', 'Messages']) {
    await expect(
      page
          .getByRole('button', { name: new RegExp(`^${label}\\b`, 'i') })
          .last(),
    ).toBeVisible();
  }
}

export async function gotoDashboard(page: Page) {
  await page.goto(dashboardPath);
  await ensureFlutterSemantics(page);
  await expectDashboardShell(page);
}

export async function gotoClasses(page: Page) {
  await page.goto(classesPath);
  await ensureFlutterSemantics(page);
  await expect(
    page.getByRole('button', { name: /^Create Class$/i }),
  ).toBeVisible({ timeout: 60_000 });
  await expect(page.getByText('Classes workspace', { exact: true })).toBeVisible();
}

export async function gotoDemoClassRoute(page: Page, suffix: string) {
  await page.goto(`/class/${demoClassId}/${suffix}`);
  await ensureFlutterSemantics(page);
}

export function escapeRegex(value: string) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
