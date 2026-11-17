import { test, expect, type Locator } from '@playwright/test';
import { execFileSync } from 'node:child_process';

test('@native-gradebook saved scores, custom policy, exam recovery and actual Excel parity', async ({ page, request }, testInfo) => {
  test.setTimeout(600_000);
  const forbidden: string[] = [];
  await page.route(/https:\/\/(identitytoolkit|securetoken|firestore)\.googleapis\.com\//, route => {
    forbidden.push(new URL(route.request().url()).hostname); return route.abort();
  });
  async function ready() {
    const enable = page.locator('button[aria-label="Enable accessibility"]').first();
    if (await enable.isVisible()) await enable.click();
    await page.waitForSelector('flt-semantics-host', { state: 'attached', timeout: 20_000 });
  }
  async function type(field: Locator, value: string) {
    for (let attempt = 0; attempt < 3; attempt++) {
      await field.click(); await field.press('ControlOrMeta+A');
      if (value) await field.pressSequentially(value, { delay: 24 });
      else await field.press('Backspace');
      if (await field.inputValue() === value) return;
    }
    await expect(field).toHaveValue(value);
  }
  await page.goto('/'); await ready();
  await type(page.getByRole('textbox', { name: 'Email' }).first(), 'browser-teacher@example.invalid');
  await type(page.getByRole('textbox', { name: 'Password' }).first(), 'FakePassword-Teacher123!');
  const signIn = page.waitForResponse(r => r.url().startsWith('http://127.0.0.1:9099/') && r.url().includes('accounts:signInWithPassword'));
  await page.getByRole('button', { name: /^Sign in$/i }).first().click();
  const uid = (await (await signIn).json()).localId;
  expect(typeof uid).toBe('string');
  await expect.poll(() => new URL(page.url()).pathname).toBe('/os/home');
  const route = '/os/class/class-science-browser/gradebook';
  const root = 'http://127.0.0.1:8180/v1/projects/demo-gradeflow-v2-staging/databases/(default)/documents/users/' + uid + '/classes/class-science-browser';
  async function stored(path: string, field: string) {
    const r = await request.get(root + path, { headers: { Authorization: 'Bearer owner' } });
    // A first save can still be in flight when polling starts.
    if (r.status() === 404) return undefined;
    expect(r.ok()).toBeTruthy();
    const f = (await r.json()).fields[field];
    return f && 'nullValue' in f ? null : Number(f?.doubleValue ?? f?.integerValue);
  }
  await page.goto(route); await ready();
  await expect(page.getByRole('button', { name: 'Export Excel', exact: true })).toBeVisible();
  await expect(page.getByRole('columnheader', { name: 'Final', exact: true })).toBeVisible();
  const savedWeights = 'Participation 25% · Homework 25% · Quizzes 25% · Classwork 25%';
  await expect(page.getByText(savedWeights, { exact: true })).toBeVisible();
  await page.getByRole('checkbox', { name: 'Quizzes', exact: true }).click();
  const quiz = page.getByRole('row', { name: /Fictional Pupil/ }).getByRole('textbox').first();
  await type(quiz, '96'); await quiz.press('Enter');
  await expect.poll(() => stored('/gradeItems/fictional-quiz/scores/synthetic-student-one', 'score')).toBe(96);
  await page.reload(); await ready();
  const row = page.getByRole('row', { name: /Fictional Pupil/ });
  await expect(row.getByRole('cell', { name: '91.50', exact: true })).toBeVisible();
  const exam = row.getByRole('textbox').first();
  for (const [value, saved] of [['80', 80], ['0', 0], ['', null], ['80', 80]] as const) {
    await type(exam, value); await exam.press('Enter');
    await expect.poll(() => stored('/exams/synthetic-student-one', 'examScore')).toBe(saved);
    await page.reload(); await ready();
    await exam.click(); await expect(exam).toHaveValue(value);
  }
  // The NEW Gradebook retains invalid edits for correction; it does not use
  // the older Exam screen's automatic restoration behavior.
  await type(exam, '101'); await exam.press('Enter');
  await expect(page.getByText(/Not saved:.*Enter a score from 0 to 100/).first()).toBeVisible();
  await expect(exam).toHaveValue('101');
  expect(await stored('/exams/synthetic-student-one', 'examScore')).toBe(80);
  await page.getByRole('button', { name: 'Export Excel', exact: true }).click();
  await expect(page.locator('flt-semantics-host').getByText('Save or correct unfinished entries before exporting.', { exact: true }).first()).toBeVisible();
  await type(exam, '80'); await exam.press('Enter');
  await expect(page.getByText('Saved', { exact: true }).first()).toBeVisible();
  await page.getByRole('button', { name: 'GPA / Exam split', exact: true }).click();
  await type(page.getByRole('textbox', { name: 'Coursework / GPA percentage', exact: true }), '70');
  await page.getByRole('button', { name: 'Apply to this class', exact: true }).click();
  await expect.poll(() => stored('', 'courseworkWeightPercent')).toBe(70);
  await page.reload(); await ready();
  await expect(page.getByText('GPA 70% + Exam 30%', { exact: true })).toBeVisible();
  await expect(page.getByText(savedWeights, { exact: true })).toBeVisible();
  await expect(row.getByRole('cell', { name: '88.05', exact: true })).toBeVisible();
  await expect(page).toHaveURL('http://127.0.0.1:7357' + route);
  await page.screenshot({ path: testInfo.outputPath('native-gradebook.png') });
  const downloading = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Export Excel', exact: true }).click();
  const download = await downloading;
  expect(download.suggestedFilename()).toBe('grades_all_classes.xlsx');
  const path = testInfo.outputPath('native-gradebook.xlsx'); await download.saveAs(path);
  const workbook = JSON.parse(execFileSync('python3', ['staging-tests/inspect-gradebook-xlsx.py', path], { encoding: 'utf8' }));
  const summary = workbook['All Classes'];
  expect(summary.rows[0].slice(7)).toEqual(['Homework', 'Quiz', 'Classwork', 'Participation', 'Process Score (saved category weights)', 'Exam Score', 'Final Grade']);
  expect(summary.rows[1][4]).toBe('synthetic-student-one');
  for (const [index, expected] of [100, 96, 90, 80, 91.5, 80, 88.05].entries()) {
    expect(summary.rows[1][index + 7]).toBeCloseTo(expected, 5);
  }
  expect(summary.formulas).toEqual([]);
  await testInfo.attach('native-gradebook.xlsx', { path, contentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' });
  // The new bulk entry action must apply to the whole class, not just the
  // currently visible row. Existing scores, legitimate zero and missing marks
  // must remain distinguishable after a grouped undo.
  await page.getByRole('button', { name: 'Fill column' }).click();
  const fill = page.getByRole('dialog', { name: 'Fill a grade column' });
  await expect(fill).toBeVisible();
  await type(fill.getByRole('textbox', { name: /Score/ }), '90');
  await fill.getByRole('button', { name: 'Review fill' }).click();
  const confirm = page.getByRole('dialog', { name: 'Confirm grade changes' });
  await expect(confirm.getByText(/2 Exam scores/)).toBeVisible();
  await confirm.getByRole('button', { name: 'Apply scores' }).click();
  await expect.poll(() => stored('/exams/synthetic-student-one', 'examScore')).toBe(90);
  await expect.poll(() => stored('/exams/synthetic-student-two', 'examScore')).toBe(90);

  await page.getByRole('button', { name: 'Undo last edit' }).click();
  await expect.poll(() => stored('/exams/synthetic-student-one', 'examScore')).toBe(80);
  await expect.poll(() => stored('/exams/synthetic-student-two', 'examScore')).toBeNull();

  // Rapid taps should respond immediately while just the final value is
  // persisted after the interaction stops (no click-by-click lockout).
  const firstRow = page.getByRole('row', { name: /Fictional Pupil/ });
  const increase = firstRow.getByRole('button', { name: 'Increase score by 1' });
  await increase.click(); await increase.click(); await increase.click();
  await expect(firstRow.getByRole('textbox').first()).toHaveValue('83');
  await expect.poll(() => stored('/exams/synthetic-student-one', 'examScore')).toBe(83);
  await page.reload(); await ready();
  await expect(page.getByRole('row', { name: /Fictional Pupil/ })
    .getByRole('textbox').first()).toHaveValue('83');

  expect(forbidden).toEqual([]);
});
