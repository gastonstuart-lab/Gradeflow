import { test, expect, type Locator } from '@playwright/test';
import { ensureFlutterSemantics } from './helpers';

test('@staging authenticated GradeFlow routes to V2 Classroom on local emulators',
    async ({ page }) => {
  test.setTimeout(600_000);
  const browserDiagnostics: string[] = [];
  const unexpectedCloudRequests: string[] = [];
  let browserPhase = 'sign-in';
  // Emulator-only builds must never silently contact live Firebase Auth or
  // Firestore. A real API-key rejection after refresh is a release blocker,
  // not a reason to weaken the navigation assertions.
  await page.context().route(
    /^https?:\/\/(identitytoolkit|securetoken|firestore)\.googleapis\.com\//,
    async (route) => {
      const endpoint = new URL(route.request().url());
      unexpectedCloudRequests.push(browserPhase + ': ' + endpoint.hostname + endpoint.pathname);
      await route.abort('blockedbyclient');
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
  // The application must prime its own per-tab emulator origin before
  // FlutterFire restores Auth. Never seed it in the test harness.
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

  browserPhase = 'screensaver';
  await ensureFlutterSemantics(page);
  await page.getByRole('button', { name: 'Personalise', exact: true }).click();
  await page.getByRole('button', { name: 'Screensaver', exact: true }).click();
  await expect(page.getByText('Automatic start on Home only')).toBeVisible();
  await page.getByRole('button', { name: 'Preview', exact: true }).click();
  await expect(page.getByText('Tap anywhere to return')).toBeVisible();
  await page.screenshot({ path: 'test-results/classroom-screensaver.png' });
  await page.getByRole('button', { name: 'Dismiss screensaver' }).click();
  await expect(page).toHaveURL(/\/os\/home$/);
  // A teacher choosing a new background on HOME must stay on Home and
  // retain that setting across Planner navigation and a browser reload.
  // This tests the real authenticated GradeFlow menu, not the isolated
  // appearance preview (which has no application router).
  browserPhase = 'appearance-home-continuity';
  await ensureFlutterSemantics(page);
  const openAppearance = async () => {
    await page.getByRole('button', { name: /Account and settings/i }).first()
      .click({ timeout: 30_000 });
    await page.getByRole('button', { name: /Appearance & colours/i })
      .click({ timeout: 15_000 });
  };
  await openAppearance();
  // Real pointer clicks, not just an isolated widget state change. A modal
  // barrier must keep every tap within this panel and never open Planner.
  await expect(page.getByText('Background glow colour')).toBeVisible();
  await page.getByRole('checkbox', { name: 'Dark', exact: true }).click();
  await expect(page).toHaveURL('http://127.0.0.1:7357/os/home');
  await expect(page.getByRole('checkbox', { name: 'Dark', exact: true }))
    .toBeChecked();
  // The reported LIVE failure also affects Aurora and Soft dots, not only
  // Neon boxes. Every appearance option must work as a real browser click,
  // remain on Home, and visibly update selected state while menu stays open.
  for (const choice of ['Aurora', 'Soft dots', 'Minimal', 'Neon boxes']) {
    const option = page.getByRole('checkbox', { name: choice, exact: true });
    await expect(option).toBeVisible();
    await option.click({ timeout: 15_000 });
    await expect(page, `${choice} must not navigate to Planner`)
      .toHaveURL('http://127.0.0.1:7357/os/home');
    await expect(option, `${choice} must be applied`).toBeChecked();
    await expect(page.getByText('Background glow colour')).toBeVisible();
  }
  await page.getByRole('button', { name: /Use cyan colour/ }).click({ timeout: 15_000 });
  await expect(page).toHaveURL('http://127.0.0.1:7357/os/home');
  await expect(page.getByText('Background glow colour')).toBeVisible();
  await page.getByRole('button', { name: 'Done', exact: true }).click();
  await expect(page).toHaveURL('http://127.0.0.1:7357/os/home');
  await page.goto('/os/planner');
  await ensureFlutterSemantics(page);
  // Personalisation entry is intentionally Home-only, not an overlay on
  // Planner, Gradebook, Classroom, or student workflows.
  await expect(page.getByRole('button', { name: /Account and settings/i }))
    .toHaveCount(0);
  await page.goto('/os/home');
  await ensureFlutterSemantics(page);
  await openAppearance();
  await expect(page.getByRole('checkbox', { name: 'Neon boxes', exact: true }))
    .toBeChecked();
  await page.getByRole('button', { name: 'Done', exact: true }).click();
  await page.reload();
  await ensureFlutterSemantics(page);
  await expect(page).toHaveURL('http://127.0.0.1:7357/os/home');
  await openAppearance();
  await expect(page.getByRole('checkbox', { name: 'Neon boxes', exact: true }))
    .toBeChecked();
  await page.getByRole('button', { name: 'Done', exact: true }).click();
  await page.screenshot({ path: 'test-results/appearance-home-after-reload.png' });

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
  browserPhase = 'upgraded-timer';
  await page.getByRole('button', { name: 'Full-page timer', exact: true }).first().click();
  await expect(page.getByText('Classroom timer', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Set timer duration' }).click();
  await expect(page.getByRole('menuitem', { name: '5 minutes', exact: true })).toBeVisible({ timeout: 15000 });
  await page.getByRole('menuitem', { name: '5 minutes', exact: true }).click({ timeout: 15000 });
  await expect(page.getByText('05:00', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: '+30 sec', exact: true }).click();
  await expect(page.getByText('05:30', { exact: true })).toBeVisible();
  await page.screenshot({ path: 'test-results/classroom-timer.png' });
  await page.getByRole('button', { name: 'Close timer' }).click();

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
    await page.context().grantPermissions(['clipboard-read', 'clipboard-write']);
    await page.evaluate((text) => navigator.clipboard.writeText(text), pastedRows);
    // Use a real paste event. Flutter can replace a DOM-only fill during
    // semantics focus activation; never proceed unless the whole input matches.
    for (let attempt = 0; attempt < 3; attempt++) {
      await rows.click();
      await rows.press('ControlOrMeta+A');
      await rows.press('ControlOrMeta+V');
      try {
        await expect(rows).toHaveValue(pastedRows, { timeout: 3_000 });
        break;
      } catch (error) {
        if (attempt === 2) throw error;
      }
    }
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
    // A Flutter semantics label can exist even when its canvas glyphs are
    // invisible. Check the actual raster of the white Home action, excluding
    // the leading icon, rounded border and outer shadow.
    async function captureReadableHomeAction(suffix: string) {
      const png = await openClassroom.screenshot({
        path: `test-results/home-action-${suffix}.png`,
        animations: 'disabled',
      });
      const pixels = await page.evaluate(async (base64) => {
        const image = new Image();
        image.src = 'data:image/png;base64,' + base64;
        await image.decode();
        const canvas = document.createElement('canvas');
        canvas.width = image.naturalWidth;
        canvas.height = image.naturalHeight;
        const ctx = canvas.getContext('2d')!;
        ctx.drawImage(image, 0, 0);
        const left = Math.floor(canvas.width * 0.40);
        const top = Math.floor(canvas.height * 0.23);
        const width = Math.max(1, Math.floor(canvas.width * 0.44));
        const height = Math.max(1, Math.floor(canvas.height * 0.54));
        const data = ctx.getImageData(left, top, width, height).data;
        let ink = 0, white = 0;
        for (let i = 0; i < data.length; i += 4) {
          const [r, g, b, a] = [data[i], data[i + 1], data[i + 2], data[i + 3]];
          if (a > 200 && r < 95 && g < 145 && b < 185 && b > r + 20) ink++;
          if (a > 200 && r > 225 && g > 225 && b > 225) white++;
        }
        const count = data.length / 4;
        return { ink: ink / count, white: white / count };
      }, png.toString('base64'));
      expect(pixels.white, `Home action white background: ${suffix}`)
        .toBeGreaterThan(0.45);
      expect(pixels.ink, `Home action visible text pixels: ${suffix}`)
        .toBeGreaterThan(0.006);
      await page.screenshot({ path: `test-results/home-legibility-${suffix}.png` });
    }
    await captureReadableHomeAction('desktop');
    const originalViewport = page.viewportSize();
    if (originalViewport) {
      try {
        await page.setViewportSize({ width: 390, height: 844 });
        await expect(openClassroom).toBeEnabled({ timeout: 15_000 });
        await captureReadableHomeAction('mobile');
      } finally {
        await page.setViewportSize(originalViewport);
      }
    }
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
  await page.getByRole('button', { name: 'Whiteboard & PDF Open Teaching Studio', exact: true }).click();
  await expect.poll(() => new URL(page.url()).pathname).toBe('/teaching-studio/');
  await expect(page.getByRole('heading', { name: 'Teaching Studio', exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Save board', exact: true })).toBeEnabled();
  // Bottom navigation must retain the Studio tab and restore signed-in Home.
  const [homeTab] = await Promise.all([
    page.waitForEvent('popup'),
    page.getByRole('link', { name: 'Home', exact: true }).click(),
  ]);
  await homeTab.waitForLoadState('domcontentloaded');
  await ensureFlutterSemantics(homeTab);
  await expect(homeTab).toHaveURL('http://127.0.0.1:7357/os/home');
  expect(await homeTab.evaluate(() => window.opener === null)).toBe(true);
  await expect.poll(() => homeTab.evaluate(() =>
    window.sessionStorage.getItem('[DEFAULT]-firebaseEmulatorOrigin')))
    .toBe('http://127.0.0.1:9099');
  await expect(homeTab.getByRole('button', { name: 'Open Classroom', exact: true })).toBeEnabled();
  await expect(page.getByRole('heading', { name: 'Teaching Studio', exact: true })).toBeVisible();
  await homeTab.close();
  expect(unexpectedCloudRequests,
    'A local-emulator build contacted live Firebase endpoints').toEqual([]);
});
