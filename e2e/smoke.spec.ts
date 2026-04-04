import { test, expect } from '@playwright/test';
import {
  ensureDemoSignedIn,
  ensureFlutterSemantics,
  expectDashboardShell,
} from './helpers';

test('login screen loads', async ({ page }) => {
  await page.goto('/');

  await ensureFlutterSemantics(page);

  await expect(page.getByText('Enter GradeFlow')).toBeVisible();

  await expect(page.getByLabel('Email')).toBeVisible();
  await expect(page.getByLabel('Password')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Sign In' })).toBeVisible();
  await expect(
    page.getByRole('button', { name: 'Continue with Google' }),
  ).toBeVisible();
  await expect(
    page.getByRole('button', { name: 'Try Demo Account' }),
  ).toBeVisible();
});

test('demo login navigates to dashboard', async ({ page }) => {
  test.setTimeout(120_000);
  await page.goto('/');

  await ensureDemoSignedIn(page);
  await expect(page).toHaveURL(/\/dashboard(?:\?|$)/);
  await expectDashboardShell(page);
});
