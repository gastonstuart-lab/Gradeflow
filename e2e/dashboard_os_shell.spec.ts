import { test, expect } from '@playwright/test';
import { ensureDemoSignedIn } from './helpers';

test('dashboard attention center and dock stay available on desktop', async ({
  page,
}) => {
  test.setTimeout(180_000);

  await page.goto('/');
  await ensureDemoSignedIn(page);

  const attentionButton = page.getByRole('button', {
    name: 'Attention center',
  });
  await expect(attentionButton).toBeVisible({ timeout: 60_000 });

  for (const label of ['Classes', 'Studio', 'Messages', 'Teach', 'All Apps']) {
    await expect(
      page
          .getByRole('button', { name: new RegExp(`^${label}\\b`, 'i') })
          .last(),
    ).toBeVisible();
  }

  await attentionButton.click();

  await expect(
    page.getByText('Notifications'),
  ).toBeVisible({ timeout: 20_000 });

  const quietState = page.getByText(/All clear/i);
  const activeSignals = page.getByText(/unread message|Admin|Today|Tomorrow|Overdue/i);
  const activeSignalCount = await activeSignals.count();

  if (activeSignalCount > 0) {
    await expect(activeSignals.first()).toBeVisible();
  } else {
    await expect(quietState).toBeVisible();
  }
});
