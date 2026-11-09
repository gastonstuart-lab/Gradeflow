import { test, expect, type Locator } from '@playwright/test';
import { ensureFlutterSemantics } from './helpers';

test('@staging authenticated GradeFlow routes to V2 Classroom on local emulators',
    async ({ page }) => {
  test.setTimeout(180_000);
  const browserDiagnostics: string[] = [];
  const unexpectedCloudRequests: string[] = [];
  let browserPhase = 'sign-in';
  // Emulator-only builds must never silently contact live Firebase Auth or
  // Firestore. A real API-key rejection after refresh is a release blocker,
  // not a reason to weaken the navigation assertions.
  page.on('request', (request) => {
    const endpoint = new URL(request.url());
    if (['identitytoolkit.googleapis.com', 'securetoken.googleapis.com',
         'firestore.googleapis.com'].includes(endpoint.hostname)) {
      unexpectedCloudRequests.push(browserPhase + ': ' + endpoint.hostname + endpoint.pathname);
    }
  });
  page.on('console', (message) => {
    if (message.text().includes('GRADEFLOW_STAGING_')) {
      browserDiagnostics.push('route: ' + message.text());
    }
    if (message.type() === 'error' || message.type() === 'warning') {
      browserDiagnostics.push(message.type() + ': ' + message.text());
    }
  });
  page.on('pageerror', (error) => browserDiagnostics.push('page: ' + error.message));
  page.on('response', (response) => {
    if (response.url().includes('identitytoolkit') ||
        response.url().includes('securetoken')) {
      browserDiagnostics.push('auth-http: ' + response.status() + ' ' +
        new URL(response.url()).pathname);
      // Log only the error code on an emulator failure; never log ID tokens
      // or successful authentication responses.
      if (response.status() >= 400) {
        void response.json().then((payload) => {
          browserDiagnostics.push('auth-error: ' +
            String(payload?.error?.message ?? 'unknown'));
        }).catch(() => {});
      }
    }
  });
  // FlutterFire's web SDK can restore a persisted user before Dart code has
  // connected the Auth emulator. Preconfigure only this loopback browser
  // fixture before any Firebase scripts execute. No real API key is used.
  // The strict network assertion below still rejects every cloud endpoint.
  await page.addInitScript(() => {
    if (window.location.hostname !== '127.0.0.1' ||
        window.location.port !== '7357') return;
    window.sessionStorage.setItem(
      'firebaseEmulatorOrigin', 'http://127.0.0.1:9099');
  });
  await page.goto('/');
  await ensureFlutterSemantics(page);

  await expect(page.getByText('Staging safety check')).toHaveCount(0);
  const email = page.getByRole('textbox', { name: 'Email' }).first();
  const password = page.getByRole('textbox', { name: 'Password' }).first();
  await expect(email).toBeVisible({ timeout: 30_000 });
  // Flutter text editing can receive fast DOM fill events before the
  // framework's controller has processed the final value. Enter keys as
  // native keyboard events and wait for the next frame before submission.
  // Flutter may ignore the first native key while bringing an editable
  // semantics node into focus. Retry the same actual keyboard input only
  // when the complete, exact value is not present; never bypass this check.
  async function typeExact(field: Locator, expectedValue: string) {
    for (let attempt = 0; attempt < 3; attempt++) {
      await field.click();
      await field.press('ControlOrMeta+A');
      await field.pressSequentially(expectedValue, { delay: 24 });
      if ((await field.inputValue()) === expectedValue) return;
    }
    await expect(field).toHaveValue(expectedValue);
  }
  await typeExact(email, 'browser-teacher@example.invalid');
  await typeExact(password, 'FakePassword-Teacher123!');
  await expect(email).toHaveValue('browser-teacher@example.invalid');
  await expect(password).toHaveValue('FakePassword-Teacher123!');
  await page.waitForTimeout(300);
  await page.getByRole('button', { name: /^Sign in$/i }).first().click();
  try {
    await expect.poll(() => new URL(page.url()).pathname, { timeout: 15_000 }).toBe('/os/home');
  } catch (error) {
    console.log('Authentication failure diagnostics:', browserDiagnostics);
    console.log('Visible browser text:',
      (await page.locator('body').innerText().catch(() => '')).slice(0, 2500));
    throw error;
  }

  console.log('Auth emulator origin after sign-in:', await page.evaluate(
    () => window.sessionStorage.getItem('firebaseEmulatorOrigin')));
  browserPhase = 'open-class';
  const directResponse = await page.goto('/os/class/class-science-browser');
  console.log('Class direct-request status and final HTTP URL:',
    directResponse?.status(), directResponse?.url());
  await ensureFlutterSemantics(page);
  try {
    await expect(page.getByText('Synthetic Science 2B').first())
      .toBeVisible({ timeout: 15_000 });
  } catch (error) {
    console.log('Class workspace URL:', page.url());
    console.log('Unexpected cloud Firebase endpoints:', unexpectedCloudRequests);
    console.log('Class workspace diagnostics:', browserDiagnostics);
    console.log('Class workspace visible text:',
      (await page.locator('body').innerText().catch(() => '')).slice(0, 3500));
    throw error;
  }

  browserPhase = 'open-classroom';
  await page.goto('/os/class/class-science-browser/classroom');
  await ensureFlutterSemantics(page);
  await expect(page.getByText('Fit to screen').first())
    .toBeVisible({ timeout: 45_000 });
  await expect(page.getByText('Present').first()).toBeVisible();

  // Returning from Classroom to Home retains authorization and class
  // context; the browser connects only to localhost demo Firebase emulators.
  browserPhase = 'return-home';
  await page.goto('/os/home');
  await ensureFlutterSemantics(page);
  await expect(page.getByText('Staging safety check')).toHaveCount(0);
  browserPhase = 'refresh-home';
  await page.reload();
  await ensureFlutterSemantics(page);
  await expect(page.getByText('Staging safety check')).toHaveCount(0);
  // A successful refresh must restore this actual teacher workspace, not
  // merely avoid the safety-blocked screen or show an unauthenticated shell.
  await expect(page).toHaveURL(/\/os\/home$/);
  await expect(page.getByText('Welcome, browser-teacher@example.invalid.').first())
    .toBeVisible({ timeout: 30_000 });
  console.log('Auth emulator origin after refresh:', await page.evaluate(
    () => window.sessionStorage.getItem('firebaseEmulatorOrigin')));
  expect(unexpectedCloudRequests,
    'A local-emulator build contacted live Firebase endpoints').toEqual([]);
});
