import { test, expect } from '@playwright/test';

// Independent browser fixture: native Flutter sample screens from
// lib/teacher_appearance_review_main.dart, NEVER production Firebase.
test('@appearance-native actual Flutter account menu is clickable at desktop and mobile sizes', async ({ page }, testInfo) => {
  test.setTimeout(100_000);
  const externalCompleted: string[] = [];
  const academicBackendRequests: string[] = [];
  page.on('request', request => {
    const host = new URL(request.url()).hostname;
    if (['firestore.googleapis.com', 'identitytoolkit.googleapis.com',
        'securetoken.googleapis.com', 'firebasestorage.googleapis.com'].includes(host)) {
      academicBackendRequests.push(host);
    }
  });
  page.on('requestfinished', request => {
    const url = new URL(request.url());
    if (url.protocol === 'https:' && url.hostname !== '127.0.0.1') {
      externalCompleted.push(url.hostname);
    }
  });

  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto('/os/home');
  await page.waitForSelector('flt-semantics-host', { state: 'attached', timeout: 25_000 });
  await expect(page.getByText('Good evening, Teacher.', { exact: true })).toBeVisible();
  // The HTML launch curtain can briefly fade after the semantics tree appears.
  await page.waitForTimeout(1800);
  await page.screenshot({ path: testInfo.outputPath('01-native-desktop-home.png') });

  await page.getByRole('button', { name: /Account and settings/i }).first().click();
  await expect(page.getByRole('button', { name: /Appearance & colours/i })).toBeVisible();
  await expect(page.getByRole('button', { name: /^Sign out/i })).toBeVisible();
  await page.screenshot({ path: testInfo.outputPath('02-native-desktop-account-menu.png') });

  await page.getByRole('button', { name: /Appearance & colours/i }).click();
  await expect(page.getByRole('checkbox', { name: 'Neon boxes' })).toBeVisible();
  await page.getByRole('checkbox', { name: 'Neon boxes' }).click();
  await page.getByRole('checkbox', { name: 'Light' }).click();
  await page.mouse.move(790, 665);
  await page.waitForTimeout(160);
  await page.screenshot({ path: testInfo.outputPath('03-native-desktop-light-neon.png') });
  await page.getByRole('button', { name: 'Done' }).click();

  await page.getByRole('button', { name: 'Gradebook' }).click();
  await expect(page.getByRole('group', { name: 'J2 Science · Sample Gradebook' })).toBeVisible();
  await expect(page.getByRole('columnheader', { name: 'Homework' })).toBeVisible();
  await page.screenshot({ path: testInfo.outputPath('04-native-gradebook.png') });

  await page.setViewportSize({ width: 390, height: 844 });
  await page.reload();
  await page.waitForSelector('flt-semantics-host', { state: 'attached', timeout: 25_000 });
  await page.getByRole('button', { name: /Account and settings/i }).first().click();
  await expect(page.getByRole('button', { name: /Appearance & colours/i })).toBeVisible();
  await page.getByRole('button', { name: /Appearance & colours/i }).click();
  await expect(page.getByText('Background glow colour', { exact: true })).toBeVisible();
  await page.screenshot({ path: testInfo.outputPath('05-native-phone-appearance.png') });

  // CSP must stop all remote connections; no real Firebase API calls.
  expect(academicBackendRequests).toEqual([]);
  expect(externalCompleted).toEqual([]);
});
