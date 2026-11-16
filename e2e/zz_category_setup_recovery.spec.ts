import { test, expect, type Locator } from '@playwright/test';
import { readFile } from 'node:fs/promises';
import { ensureFlutterSemantics } from './helpers';

test('@category-setup preserves one class after rejected grading setup and recovers', async ({ page, request }) => {
  test.setTimeout(600_000);
  const project = 'demo-gradeflow-v2-staging';
  const originalRules = await readFile('firestore.staging.rules', 'utf8');
  const unexpected: string[] = [];

  page.on('request', req => {
    const host = new URL(req.url()).hostname;
    if (['firestore.googleapis.com', 'identitytoolkit.googleapis.com', 'securetoken.googleapis.com'].includes(host)) {
      unexpected.push(host);
    }
  });

  async function rules(extra = '') {
    const content = originalRules.replace(
      /allow read, write: if request.auth != null\s*&& request.auth.uid == teacherUid;/,
      'allow read: if request.auth != null && request.auth.uid == teacherUid;\n'
      + 'allow write: if request.auth != null && request.auth.uid == teacherUid ' + extra + ';'
    );
    expect(content).toContain('allow read: if request.auth != null');
    const response = await request.put(
      'http://127.0.0.1:8180/emulator/v1/projects/' + project + ':securityRules',
      { data: { rules: { files: [{ content }] } } },
    );
    expect(response.ok()).toBeTruthy();
  }

  async function type(field: Locator, text: string) {
    for (let attempt = 0; attempt < 3; attempt++) {
      await field.click();
      await field.press('ControlOrMeta+A');
      await field.pressSequentially(text, { delay: 12 });
      if (await field.inputValue() === text) return;
    }
    await expect(field).toHaveValue(text);
  }

  const semantics = page.locator('flt-semantics-host');
  await page.goto('/');
  await ensureFlutterSemantics(page);
  await type(page.getByRole('textbox', { name: 'Email' }).first(), 'browser-teacher@example.invalid');
  await type(page.getByRole('textbox', { name: 'Password' }).first(), 'FakePassword-Teacher123!');
  const signedIn = page.waitForResponse(r => r.url().includes('accounts:signInWithPassword'));
  await page.getByRole('button', { name: /^Sign in$/i }).first().click();
  const uid = (await (await signedIn).json()).localId;
  expect(typeof uid).toBe('string');

  const documents = 'http://127.0.0.1:8180/v1/projects/' + project + '/databases/(default)/documents/users/' + uid;
  async function collection(path: string) {
    const response = await request.get(documents + '/' + path, {
      headers: { Authorization: 'Bearer owner' },
    });
    expect(response.ok()).toBeTruthy();
    return (await response.json()).documents ?? [];
  }

  try {
    await expect.poll(() => new URL(page.url()).pathname).toBe('/os/home');
    await page.goto('/classes');
    await ensureFlutterSemantics(page);
    await page.getByRole('button', { name: 'Create Class', exact: true }).first().click();

    const name = 'Fictional Category Recovery';
    await type(page.getByRole('textbox', { name: /^Class Name/ }), name);
    await type(page.getByRole('textbox', { name: /^Subject/ }), 'Science');

    // Deny only category documents with the default Participation name;
    // the class document may still be saved. Never target live Firebase.
    await rules("&& (!('name' in request.resource.data) || request.resource.data.name != 'Participation')");
    await page.getByRole('button', { name: 'Create', exact: true }).click();
    await expect(semantics.getByText(/The class was saved, but its default grading categories were not/)).toBeVisible();

    const savedClasses = (await collection('classes'))
      .filter((doc: any) => doc.fields.className?.stringValue === name);
    expect(savedClasses).toHaveLength(1);
    const id = savedClasses[0].fields.classId.stringValue;
    expect(await collection('classes/' + id + '/categories')).toHaveLength(0);

    await rules();
    await page.getByRole('button', { name: 'Retry grading setup', exact: true }).click();
    await expect(semantics.getByText('Class created', { exact: true })).toBeVisible();

    const persistedClasses = (await collection('classes'))
      .filter((doc: any) => doc.fields.className?.stringValue === name);
    expect(persistedClasses).toHaveLength(1);
    const categories = await collection('classes/' + id + '/categories');
    expect(categories).toHaveLength(4);
    expect(categories.map((doc: any) => doc.fields.name?.stringValue).sort())
      .toEqual(['Classwork', 'Homework', 'Participation', 'Quiz']);

    await page.reload();
    await ensureFlutterSemantics(page);
    await expect(page.getByRole('group', { name: /^Fictional Category Recovery Science Active/ })).toBeVisible();
    expect(await collection('classes/' + id + '/categories')).toHaveLength(4);
    expect(unexpected).toEqual([]);
    console.log('Category recovery: durable class stayed unique, grading setup retried and survived reload');
  } finally {
    await rules();
  }
});
