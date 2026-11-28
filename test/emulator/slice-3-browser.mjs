import assert from 'node:assert/strict';
import { chromium } from '@playwright/test';

const browser = await chromium.launch({ args: ['--no-sandbox'] });
const page = await browser.newPage({ viewport: { width: 1440, height: 1050 } });
page.setDefaultTimeout(15000);
page.on('pageerror', error => console.error('Browser error:', error));
page.on('console', message => {
  if (message.type() === 'error') console.error(message.text());
});

const label = name => page.getByLabel(name, { exact: true });
const text = name => page.getByText(name, { exact: true }).or(label(name)).first();
const status = fragment => page.getByText(fragment, { exact: false })
  .or(page.locator(`flt-semantics[aria-label*=${JSON.stringify(fragment)}]`)).first();
const button = name => page.getByRole('button', { name, exact: true });
const period = name => button(`Grading period ${name}`).or(button(name)).or(text(name)).first();
const visible = async locator => locator.waitFor({ state: 'visible' });

async function click(locator) {
  await visible(locator);
  await locator.dispatchEvent('click');
}

async function screenshot(name) {
  await page.screenshot({ path: `evidence/${name}.png` });
}

async function selectPeriod(current, target) {
  await click(period(current));
  await click(period(target));
}

async function scoreRow(value) {
  const field = page.getByRole('textbox', {
    name: new RegExp(`ID S01, Seat 1, score ${value}`),
  });
  await visible(field);
  return field;
}

try {
  const requests = [];
  const outcomes = [];
  let interruptNext = false;
  await page.route('http://127.0.0.1:8787/rollover', async route => {
    if (route.request().method() !== 'POST') return route.continue();
    requests.push(route.request().postData());
    if (!interruptNext) return route.continue();
    interruptNext = false;
    const response = await route.fetch({
      headers: { ...route.request().headers(), 'x-test-fault': 'after-commit' },
    });
    outcomes.push(response.status());
    await route.fulfill({ response });
  });

  await page.goto('http://127.0.0.1:7357/');
  await visible(button('New grading period'));
  let editFailure;
  try {
    await scoreRow('blank');
    const slider = page.getByRole('slider').first();
    await visible(slider);
    const box = await slider.boundingBox();
    assert(box, 'Expected the quick-grade slider');
    await page.mouse.click(box.x + box.width * 0.72, box.y + box.height / 2);

    const edited = await scoreRow('[1-9][0-9]? of 100');
    const editedName = await edited.ariaSnapshot();
    const score = /score (\d+) of 100/.exec(editedName)?.[1];
    assert(score, editedName);
    await visible(text('All changes saved'));
    await click(button('Reload'));
    await scoreRow(`${score} of 100`);
    await screenshot('01-active-period-persisted-edit');
    console.log(`PASS active-period editing: Alex score ${score} persisted across reload`);
  } catch (error) {
    editFailure = error;
    console.error('Active-period editing failed:', error);
    console.error(await page.locator('body').ariaSnapshot());
    await screenshot('01-active-edit-failure');
    if (await button('Dismiss').count()) await click(button('Dismiss'));
  }

  await selectPeriod('December · Active', 'November · Archived');
  const exportButton = button('Export historical Excel');
  await visible(exportButton);
  await visible(text('88.00').first());
  assert.equal(await button('New grading period').count(), 0);
  assert.equal(await button('Add item').count(), 0);
  assert.equal(await page.getByRole('textbox').count(), 0);
  await screenshot('02-read-only-november');
  console.log('PASS read-only archive: November grades visible and edit controls absent');

  const downloading = page.waitForEvent('download');
  await click(exportButton);
  const download = await downloading;
  assert.equal(download.suggestedFilename(),
    'historical_synthetic-preview-gradebook_preview-period-1.xlsx');
  await download.saveAs('evidence/historical.xlsx');
  console.log('Captured historical Excel download');
  await visible(text('Historical Excel exported'));
  await screenshot('03-historical-excel-export');

  await selectPeriod('November · Archived', 'December · Active');
  await click(button('New grading period'));
  await visible(text('Start a new grading period'));
  const name = page.getByRole('textbox', { name: /New period name/ });
  await visible(name);
  await page.keyboard.type('January acceptance');
  interruptNext = true;
  await click(button('Archive current & start'));
  await visible(button('Recover rollover'));
  await visible(status('Rollover is unconfirmed.'));
  assert.deepEqual(outcomes, [503]);
  await screenshot('04-rollover-response-interrupted');

  const pendingIntent = await page.evaluate(() => Object.keys(localStorage)
    .filter(key => key.includes('grading-period-preview:v1:'))
    .map(key => {
      const stored = JSON.parse(localStorage.getItem(key));
      return typeof stored === 'string' ? JSON.parse(stored) : stored;
    }));
  assert.equal(pendingIntent.length, 1);
  assert.equal(pendingIntent[0].label, 'January acceptance');
  assert.deepEqual(pendingIntent[0], JSON.parse(requests.at(-1)));
  await click(button('Reload'));
  await visible(status('Rollover outcome unconfirmed.'));
  const recovering = page.waitForResponse(response =>
    response.url() === 'http://127.0.0.1:8787/rollover' &&
    response.request().method() === 'POST' && response.status() === 200);
  await click(button('Recover rollover'));
  await visible(text('Grading period ready · 20 editable assessments'));
  const rolloverRequests = requests.filter(body => JSON.parse(body).label === 'January acceptance');
  assert.equal(rolloverRequests.length, 2);
  assert.equal(rolloverRequests[0], rolloverRequests[1], 'Recovery must send identical retained intent');
  assert.equal(await button('Recover rollover').count(), 0);
  const { book, receipt, replayed } = await (await recovering).json();
  assert.equal(replayed, true);
  assert.equal(receipt.toPeriodId, pendingIntent[0].nextPeriodId);
  assert.equal(book.activePeriodId, pendingIntent[0].nextPeriodId);
  assert.equal(book.periods.length, 3);
  assert.equal(book.periods.filter(item => item.label === 'January acceptance').length, 1);
  await screenshot('05-rollover-recovered');
  console.log('PASS interrupted rollover: post-commit 503, durable intent, and identical intent replay');

  const choose = name => label(name).or(text(name)).or(button(name)).first();
  const groups = [['Quiz', 2], ['Classwork', 6], ['Homework', 6], ['Participation', 6]];
  const active = book.periods.find(item => item.periodId === book.activePeriodId);
  const expected = groups.flatMap(([category, count]) =>
    Array.from({length: count}, (_, index) => `${category} ${index + 1}`));
  assert.deepEqual(active.dataset.assessments.filter(item => item.isActive)
    .map(item => item.name).sort(), expected.sort());
  console.log('PASS all 20 default assessments: 2 Quiz, 6 Classwork, 6 Homework, 6 Participation');

  let previousCategory = 'Quiz';
  for (const [category, count] of groups) {
    if (category !== previousCategory) {
      await click(button(`Category ${previousCategory}`));
      await click(choose(category));
    }
    await click(page.getByRole('button', { name: /^Assessment(?: |$)/ }).first());
    for (let number = 1; number <= count; number++) {
      await visible(choose(`${category} ${number}`));
    }
    assert.equal(await choose(`${category} ${count + 1}`).count(), 0);
    await screenshot(`06-defaults-${category.toLowerCase()}`);
    await click(choose(`${category} 1`));
    previousCategory = category;
  }
  if (editFailure) throw editFailure;
} catch (error) {
  await screenshot('failure').catch(() => {});
  console.error(await page.locator('body').ariaSnapshot().catch(() => 'No accessibility snapshot'));
  throw error;
} finally {
  await browser.close();
}
