import { test, expect, type Locator } from '@playwright/test';
import { readFile } from 'node:fs/promises';
import { ensureFlutterSemantics } from './helpers';

test('@class-setup saves, retries and reopens fictional class and shared room', async ({ page, request }) => {
  test.setTimeout(900_000);
  const project = 'demo-gradeflow-v2-staging';
  const originalRules = await readFile('firestore.staging.rules', 'utf8');
  const unexpected: string[] = [];
  page.on('request', r => {
    if (['firestore.googleapis.com', 'identitytoolkit.googleapis.com', 'securetoken.googleapis.com'].includes(new URL(r.url()).hostname)) unexpected.push(new URL(r.url()).hostname);
  });
  async function rules(extra = '') {
    // This test can only change the localhost demo emulator's in-memory rules.
    const content = originalRules.replace(
      /allow read, write: if request.auth != null\s*&& request.auth.uid == teacherUid;/,
      'allow read: if request.auth != null && request.auth.uid == teacherUid;\n'
      + 'allow write: if request.auth != null && request.auth.uid == teacherUid ' + extra + ';');
    expect(content).toContain('allow read: if request.auth != null');
    const response = await request.put('http://127.0.0.1:8180/emulator/v1/projects/' + project + ':securityRules', { data: { rules: { files: [{ content }] } } });
    expect(response.ok()).toBeTruthy();
  }
  async function type(field: Locator, text: string) {
    for (let attempt = 0; attempt < 3; attempt++) {
      await field.click(); await field.press('ControlOrMeta+A'); await field.pressSequentially(text, { delay: 18 });
      if (await field.inputValue() === text) return;
    }
    await expect(field).toHaveValue(text);
  }
  async function open(path: string) { await page.goto(path); await ensureFlutterSemantics(page); }
  const semantics = page.locator('flt-semantics-host');
  await open('/');
  await type(page.getByRole('textbox', { name: 'Email' }).first(), 'browser-teacher@example.invalid');
  await type(page.getByRole('textbox', { name: 'Password' }).first(), 'FakePassword-Teacher123!');
  const signedIn = page.waitForResponse(r => r.url().includes('accounts:signInWithPassword'));
  await page.getByRole('button', { name: /^Sign in$/i }).first().click();
  const uid = (await (await signedIn).json()).localId;
  expect(typeof uid).toBe('string');
  const documents = 'http://127.0.0.1:8180/v1/projects/' + project + '/databases/(default)/documents/users/' + uid;
  async function collection(path: string) {
    const response = await request.get(documents + '/' + path, { headers: { Authorization: 'Bearer owner' } });
    expect(response.ok()).toBeTruthy();
    return (await response.json()).documents ?? [];
  }
  try {
    await expect.poll(() => new URL(page.url()).pathname).toBe('/os/home');
    await open('/classes');
    await page.getByRole('button', { name: 'Create Class', exact: true }).first().click();
    await type(page.getByRole('textbox', { name: /^Class Name/ }), 'Fictional Setup Class');
    await type(page.getByRole('textbox', { name: /^Subject/ }), 'Science');
    await rules("&& (!('className' in request.resource.data) || request.resource.data.className != 'Fictional Setup Class')");
    await page.getByRole('button', { name: 'Create', exact: true }).click();
    await expect(semantics.getByText(/Class creation did not complete/)).toBeVisible();
    console.log('Class setup: denied class write reached the retained form');
    await expect(page.getByRole('textbox', { name: /^Class Name/ })).toHaveValue('Fictional Setup Class');
    expect((await collection('classes')).filter((d: any) => d.fields.className?.stringValue === 'Fictional Setup Class')).toHaveLength(0);
    await page.screenshot({ path: 'test-results/class-create-failed-retained.png' });
    await rules();
    await page.getByRole('button', { name: 'Create', exact: true }).click();
    await expect(semantics.getByText('Class created', { exact: true })).toBeVisible();
    const created = (await collection('classes')).filter((d: any) => d.fields.className?.stringValue === 'Fictional Setup Class');
    expect(created).toHaveLength(1);
    const id = created[0].fields.classId.stringValue;
    expect(id).toMatch(/^[a-f0-9-]+$/);
    await page.reload(); await ensureFlutterSemantics(page);
    await expect(page.getByRole('group', { name: /^Fictional Setup Class Science Active/ })).toBeVisible();
    console.log('Class setup: successful retry survived reload');
    await open('/os/class/' + id + '/students');
    await page.getByRole('button', { name: 'Paste from spreadsheet', exact: true }).click();
    const rows = page.getByRole('textbox', { name: /Roster rows/ });
    const data = 'studentId\tchineseName\tenglishFirstName\tenglishLastName\nsetup-101\tFictional\tFirst\tPupil\nsetup-102\tFictional\tSecond\tPupil';
    await page.context().grantPermissions(['clipboard-read', 'clipboard-write']);
    await page.evaluate(text => navigator.clipboard.writeText(text), data);
    for (let attempt = 0; attempt < 3; attempt++) { await rows.click(); await rows.press('ControlOrMeta+A'); await rows.press('ControlOrMeta+V'); if (await rows.inputValue() === data) break; }
    await expect(rows).toHaveValue(data); await rows.press('Tab');
    await page.getByRole('button', { name: 'Preview', exact: true }).click();
    await page.getByRole('button', { name: 'Import 2 students', exact: true }).click();
    await expect(semantics.getByText(/Imported 2 students/)).toBeVisible();
    await page.getByRole('button', { name: 'Add student', exact: true }).first().click();
    for (const [name, value] of [['Student ID', 'setup-103'], ['Chinese name', 'Fictional'], ['English first name', 'Missing'], ['English last name', 'Pupil']]) await type(page.getByRole('textbox', { name: new RegExp('^' + name) }), value);
    await page.getByRole('button', { name: 'Add student', exact: true }).last().click();
    await expect(semantics.getByText(/Student added to Fictional Setup Class/)).toBeVisible();
    await page.reload(); await ensureFlutterSemantics(page);
    await expect(page.getByRole('group', { name: /Missing Pupil ID: setup-103/ })).toBeVisible();
    expect(await collection('classes/' + id + '/students')).toHaveLength(3);
    console.log('Class setup: imported pupils and missing pupil survived reload');
    await open('/os/class/' + id + '/classroom?setup=1');
    await page.getByText('Add table', { exact: true }).click();
    await expect.poll(async () => (await collection('classes/' + id + '/seatingLayouts'))[0]?.fields.tables.arrayValue.values?.length ?? 0).toBeGreaterThan(0);
    const previousLayouts = (await collection('classes/' + id + '/seatingLayouts')).map((d: any) => ({ name: d.name, fields: d.fields }));
    const previousMeta = (await collection('classes/' + id + '/seatingMeta'))[0].fields;
    await open('/os/class/class-science-browser/classroom?setup=1');
    await page.getByText('Use this room for other classes', { exact: true }).click();
    await page.getByRole('checkbox', { name: 'All other classes', exact: true }).click();
    await page.getByRole('checkbox', { name: 'Fictional Setup Class', exact: true }).click();
    // Deny only target metadata. Furniture may save first: compensation must
    // preserve the old target map and must never count this as completion.
    await rules('&& request.path != /databases/$(database)/documents/users/$(teacherUid)/classes/' + id + '/seatingMeta/default');
    await page.getByRole('button', { name: 'Reuse room', exact: true }).click();
    await expect(semantics.getByText(/Room shared with 0 of 1 classes.*Sharing stopped/)).toBeVisible({ timeout: 120_000 });
    console.log('Class setup: rejected room write reached the teacher');
    expect((await collection('classes/' + id + '/seatingLayouts')).map((d: any) => ({ name: d.name, fields: d.fields }))).toEqual(previousLayouts);
    expect((await collection('classes/' + id + '/seatingMeta'))[0].fields.activeLayoutId).toEqual(previousMeta.activeLayoutId);
    console.log('Class setup: rejected room write preserved the previous durable layout');
    await page.screenshot({ path: 'test-results/room-share-save-rejected.png' });
    await rules();
    await page.getByText('Use this room for other classes', { exact: true }).click();
    await page.getByRole('checkbox', { name: 'All other classes', exact: true }).click();
    await page.getByRole('checkbox', { name: 'Fictional Setup Class', exact: true }).click();
    await page.getByRole('button', { name: 'Reuse room', exact: true }).click();
    await expect(semantics.getByText(/Room shared with 1 of 1 classes/)).toBeVisible();
    console.log('Class setup: room retry completed');
    await open('/os/class/' + id + '/classroom');
    await expect(page.getByText('Fit to screen').first()).toBeVisible();
    await page.reload(); await ensureFlutterSemantics(page);
    const layouts = await collection('classes/' + id + '/seatingLayouts');
    const metadata = (await collection('classes/' + id + '/seatingMeta'))[0].fields;
    const active = layouts.find((d: any) => d.fields.layoutId.stringValue === metadata.activeLayoutId.stringValue);
    expect(active.fields.tables.arrayValue.values).toHaveLength(1);
    expect(active.fields.seats.arrayValue.values.every((s: any) => !s.mapValue.fields.studentId?.stringValue)).toBeTruthy();
    expect(await collection('classes/' + id + '/students')).toHaveLength(3);
    await page.screenshot({ path: 'test-results/class-room-reopened.png' });
    expect(unexpected).toEqual([]);
  } finally { await rules(); }
});

