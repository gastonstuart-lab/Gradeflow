import { test, expect } from '@playwright/test';
import {
  ensureDemoSignedIn,
  ensureFlutterSemantics,
  expectDashboardShell,
} from './helpers';

test('@smoke login screen loads', async ({ page }) => {
  await page.goto('/');

  await ensureFlutterSemantics(page);

  await expect(page.getByText('InstructOS')).toBeVisible();
  await expect(page.getByText('Sign in')).toBeVisible();

  await expect(page.getByLabel('Email')).toBeVisible();
  await expect(page.getByLabel('Password')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Enter' })).toBeVisible();
  await expect(
    page.getByRole('button', { name: 'Continue with Google' }),
  ).toBeVisible();
  await expect(
    page.getByRole('button', { name: 'Open demo' }),
  ).toBeVisible();
});

test('@smoke demo login opens authenticated workspace', async ({ page }) => {
  test.setTimeout(420_000);
  await page.goto('/');

  await ensureDemoSignedIn(page);
  await expectDashboardShell(page);
});
