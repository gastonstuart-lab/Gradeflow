import { chromium, expect } from '@playwright/test';
import { mkdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';

const base = 'https://gradeflow-pr173-full-review-n20s02dfa.vercel.app/';
const commit = 'd46df7cb33416de799c611b378dd7ddf762fb31b';
const origin = new URL(base).origin;
const manifestResponse = await fetch(new URL('review-manifest.json', base));
if (!manifestResponse.ok) throw Error('Preview manifest unavailable');
const manifest = await manifestResponse.json();
expect(manifest.commit).toBe(commit);
const js = await fetch(new URL('main.dart.js', base));
if (!js.ok) throw Error('Preview JavaScript unavailable');
expect(createHash('sha256').update(Buffer.from(await js.arrayBuffer())).digest('hex'))
  .toBe(manifest.files['main.dart.js']);

await mkdir('preview-evidence', {recursive:true});
const browser = await chromium.launch({headless:true});
const context = await browser.newContext({
  viewport:{width:1440,height:900}, serviceWorkers:'block'
});
const outside = [];
await context.route('**/*', async route => {
  const url = new URL(route.request().url());
  if (url.protocol.startsWith('http') && url.origin !== origin) {
    outside.push(url.origin);
    return route.abort();
  }
  await route.continue();
});
const page = await context.newPage();
const semantics = async () => {
  const enable = page.locator('button[aria-label="Enable accessibility"]').first();
  if (await enable.isVisible().catch(()=>false)) await enable.click();
  // Flutter's semantics host is a zero-size container. Its descendants
  // are interactive even when the host itself fails the visibility check.
  await page.waitForSelector('flt-semantics-host', {state:'attached', timeout:60000});
};
const host = page.locator('flt-semantics-host');
const action = () => host.getByText('Participation demo', {exact:true});
const score = n => host.getByText(n+' / 100', {exact:true});
const close = () => page.getByRole('button',{name:'Close participation demo',exact:true}).click();
async function occupiedSeats() {
  const seats = host.getByRole('button',{name:/\bSeat for\s+\S+/});
  await expect.poll(()=>seats.count(),{timeout:60000}).toBeGreaterThan(1);
  return seats;
}
async function openSeat(seats, index) {
  await seats.nth(index).click();
  await expect(action()).toBeVisible();
  await action().click();
  await expect(host.getByText('Participation demo · Session only',{exact:true})).toBeVisible();
}
try {
  await page.goto(base);
  await semantics();
  await page.getByRole('button',{name:'Open demo workspace',exact:true}).click({timeout:60000});
  await expect(page.getByRole('button',{name:'Open Classroom',exact:true})).toBeEnabled({timeout:90000});
  await page.getByRole('button',{name:'Open Classroom',exact:true}).click();
  await expect(page.getByText('Fit to screen').first()).toBeVisible({timeout:60000});
  const classroomURL = page.url();
  const seats = await occupiedSeats();
  await openSeat(seats,0);
  await expect(score(100)).toBeVisible();
  const eating = page.getByRole('button',{name:/^Eating\s+−10$/});
  await eating.click(); await expect(score(90)).toBeVisible();
  await eating.click(); await expect(score(80)).toBeVisible();
  await page.screenshot({path:'preview-evidence/participation-two-incidents.png'});
  await page.getByRole('button',{name:'Undo last change',exact:true}).click();
  await expect(score(90)).toBeVisible();
  await close();
  await page.getByRole('button',{name:'Close tools',exact:true}).click();
  await openSeat(seats,1);
  await expect(score(100)).toBeVisible();
  await close();
  await page.getByRole('button',{name:'Close tools',exact:true}).click();
  await openSeat(seats,0);
  await expect(score(90)).toBeVisible();
  await close();
  await page.getByRole('button',{name:'Close tools',exact:true}).click();
  await page.getByRole('button',{name:'Present',exact:true}).click();
  await expect(host.getByText('Exit presentation',{exact:true})).toBeVisible();
  await expect(action()).toHaveCount(0);
  await expect(score(90)).toHaveCount(0);
  await page.screenshot({path:'preview-evidence/participation-projector.png'});
  await page.getByText('Exit presentation',{exact:true}).click();
  await page.goto(classroomURL);
  await semantics();
  await openSeat(await occupiedSeats(),0);
  await expect(score(100)).toBeVisible();
  expect(outside.filter(h=>/googleapis|firebase|google\.com/i.test(h))).toEqual([]);
  console.log('Verified deployed fictional participation preview:',commit);
} catch(error) {
  console.log('Accessibility:', await page.locator('body').ariaSnapshot().catch(()=> 'unavailable'));
  await page.screenshot({path:'preview-evidence/participation-failure.png'}).catch(()=>{});
  throw error;
} finally {
  await browser.close();
}
