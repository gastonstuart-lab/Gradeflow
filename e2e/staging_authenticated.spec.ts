import { test, expect, type Locator } from '@playwright/test';
import { ensureFlutterSemantics } from './helpers';

test('@staging authenticated GradeFlow routes to V2 Classroom on local emulators',
    async ({ page }) => {
  test.setTimeout(300_000);
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
  // Let FlutterFire itself store the per-app emulator origin in debug mode.
  // The previous fixture wrote the wrong sessionStorage key and masked
  // the fact that the app was compiled in release mode.
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

  // Exercise the actual authenticated Planner route, not the synthetic shell.
  await page.goto('/os/planner');
  await ensureFlutterSemantics(page);
  await expect(page.getByText('Import timetable', { exact: true }).first()).toBeVisible();
  for (const view of ['Today', 'Month', 'Agenda', 'Tasks', 'Week']) {
    try {
      await page.getByRole('checkbox', { name: view, exact: true }).click({ timeout: 15_000 });
    } catch (error) {
      console.log('Planner accessibility at failed view:', view);
      console.log(await page.locator('body').ariaSnapshot());
      throw error;
    }
    await expect(page).toHaveURL('http://127.0.0.1:7357/os/planner');
  }

  const emulatorOrigin = () => page.evaluate(
    () => window.sessionStorage.getItem('[DEFAULT]-firebaseEmulatorOrigin'));
  await expect.poll(emulatorOrigin).toBe('http://127.0.0.1:9099');
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

  // The real Flutter gradebook must read canonical fictional Firestore data,
  // save a changed score, and restore it after a full document reload.
  // This closes the gap left by navigation-only UI tests and SDK-only writes.
  browserPhase = 'save-grade';
  await page.goto('/os/class/class-science-browser/gradebook');
  await ensureFlutterSemantics(page);
  await expect(page.getByText('Gradebook').first()).toBeVisible();
  // Flutter's DataTable publishes the quiz title as one composite
  // columnheader ('Fictional Quiz out of 100'), not a standalone text node.
  // Locate the score field within its fictional pupil row so the test
  // verifies actual gradebook data rather than a text-layout implementation.
  // Full Gradebook opens Summary; select the actual assessment category.
  await page.getByRole('checkbox', { name: 'Quizzes', exact: true }).click();
  await expect(page.getByRole('columnheader', { name: /Fictional Quiz/ }))
    .toBeVisible({ timeout: 30_000 });
  const quizScore = page.getByRole('row', { name: /Fictional Pupil/ })
    .getByRole('textbox').first();
  // The Flutter semantics input is an editing proxy and can be empty
  // until focused even while the painted score is 94. The computed Average
  // cell is user-visible read-back from the loaded gradebook model.
  await expect(page.getByRole('row', { name: /Fictional Pupil/ })
    .getByRole('cell', { name: '94', exact: true }))
    .toBeVisible({ timeout: 30_000 });
  await typeExact(quizScore, '96');
  await quizScore.press('Enter');
  await expect(page.getByText('Saved', { exact: true }).first())
    .toBeVisible({ timeout: 30_000 });

  browserPhase = 'reload-grade';
  await page.reload();
  await ensureFlutterSemantics(page);
  await expect(page.getByText('Gradebook').first()).toBeVisible();
  await page.getByRole('checkbox', { name: 'Quizzes', exact: true }).click();
  // After a full reload, the computed average must reflect the saved quiz.
  // This checks durable Firestore data, not the transient DOM editing proxy.
  await expect(page.getByRole('row', { name: /Fictional Pupil/ })
    .getByRole('cell', { name: '96', exact: true }))
    .toBeVisible({ timeout: 30_000 });

  // Import through the real roster UI, then re-read Firestore by reloading.
  // A duplicate must stay in the preview and must not replace the pupil.
  browserPhase = 'import-roster';
  await page.goto('/os/class/class-science-browser/students');
  await ensureFlutterSemantics(page);
  await expect(page.getByRole('group', { name: /Fictional Pupil ID: synthetic-student-one/ })).toBeVisible();
  async function previewPastedRoster(id: string) {
    await page.getByRole('button', { name: 'Paste from spreadsheet', exact: true }).click();
    const rows = page.getByRole('textbox', { name: /Roster rows/ });
    const pastedRows = 'studentId\tchineseName\tenglishFirstName\tenglishLastName\n'
      + id + '\tFictional Import\tImport\tPupil, Jr';
    await rows.fill(pastedRows);
    await expect(rows).toHaveValue(pastedRows);
    await rows.press('Tab');
    await page.getByRole('button', { name: 'Preview', exact: true }).click();
    await expect(page.getByText('Import Preview', { exact: true })).toBeVisible();
  }
  await previewPastedRoster('synthetic-import-102');
  await page.screenshot({ path: 'test-results/roster-import-preview.png' });
  await page.getByRole('button', { name: 'Import 1 student', exact: true }).click();
  await expect(page.locator('flt-semantics-host').getByText(/Imported 1 student/)).toBeVisible();
  await page.reload();
  await ensureFlutterSemantics(page);
  await expect(page.getByRole('group', { name: /Import Pupil, Jr ID: synthetic-import-102/ })).toBeVisible();
  await expect(page.getByRole('group', { name: /Fictional Pupil ID: synthetic-student-one/ })).toBeVisible();
  await previewPastedRoster('synthetic-import-102');
  await page.getByRole('button', { name: 'Import 1 student', exact: true }).click();
  await expect(page.locator('flt-semantics-host').getByText(/Import was not completed.*already in this class/)).toBeVisible();
  await page.screenshot({ path: 'test-results/roster-duplicate-rejected.png' });
  await expect(page.getByText('Import Preview', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Cancel', exact: true }).click();
  // Importing a student must not disturb the existing student's saved score.
  await page.goto('/os/class/class-science-browser/gradebook');
  await ensureFlutterSemantics(page);
  await page.getByRole('checkbox', { name: 'Quizzes', exact: true }).click();
  await expect(page.getByRole('row', { name: /Fictional Pupil/ })
    .getByRole('cell', { name: '96', exact: true })).toBeVisible();

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
  // Restore Home and use its real class action instead of a decorative heading.
  const openClassroom = page.getByRole('button', { name: 'Open Classroom', exact: true });
  try {
    await expect(openClassroom).toBeEnabled({ timeout: 15_000 });
    await openClassroom.click({ timeout: 15_000 });
    await expect.poll(() => ['/os/class/class-science-browser/classroom',
      '/os/class/class-english-browser/classroom'].includes(new URL(page.url()).pathname)).toBe(true);
  } catch (error) {
    console.log('Restored Home accessibility:', await page.locator('body').ariaSnapshot());
    throw error;
  }
  await expect.poll(emulatorOrigin).toBe('http://127.0.0.1:9099');
  browserPhase = 'teaching-studio';
  await page.goto('/os/home');
  await ensureFlutterSemantics(page);
  await page.getByText('Whiteboard & PDF', { exact: true }).click();
  await expect.poll(() => new URL(page.url()).pathname).toBe('/teaching-studio/');
  await expect(page.getByRole('heading', { name: 'Teaching Studio', exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Save board', exact: true })).toBeEnabled();
  // Bottom navigation must retain the Studio tab and restore signed-in Home.
  const [homeTab] = await Promise.all([
    page.waitForEvent('popup'),
    page.getByRole('link', { name: 'Home', exact: true }).click(),
  ]);
  await ensureFlutterSemantics(homeTab);
  await expect(homeTab).toHaveURL('http://127.0.0.1:7357/os/home');
  await expect(homeTab.getByRole('button', { name: 'Open Classroom', exact: true })).toBeEnabled();
  await expect(page.getByRole('heading', { name: 'Teaching Studio', exact: true })).toBeVisible();
  await homeTab.close();
  expect(unexpectedCloudRequests,
    'A local-emulator build contacted live Firebase endpoints').toEqual([]);
});
