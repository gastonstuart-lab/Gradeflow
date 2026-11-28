import { chromium, expect } from '@playwright/test';
import { mkdir } from 'node:fs/promises';
const base = process.env.PREVIEW_URL;
if (!/^https:\/\/gradeflow-20260113--classroom-experience-review-[a-z0-9-]+\.web\.app\/?$/.test(base ?? '')) throw Error('Wrong preview host');
const browser = await chromium.launch({headless:true});
const context = await browser.newContext({ viewport: {width:1440,height:900}, serviceWorkers:'block' });
const outside = [];
await context.route('**/*', async route => {
  const url = new URL(route.request().url());
  if (url.protocol.startsWith('http') && url.origin !== new URL(base).origin) {
    outside.push(url.origin);
    return route.abort();
  }
  await route.continue();
});
await mkdir('preview-evidence',{recursive:true});
const page = await context.newPage();
async function semantics() {
  const enable = page.locator('button[aria-label="Enable accessibility"]').first();
  if (await enable.isVisible().catch(()=>false)) await enable.click();
  await page.waitForSelector('flt-semantics-host',{timeout:60000});
}
try {
  await page.goto(base);
  await semantics();
  await page.getByRole('button',{name:'Open demo workspace',exact:true}).click({timeout:60000});
  await expect(page.getByRole('button',{name:'Open Classroom',exact:true})).toBeEnabled({timeout:90000});
  await page.screenshot({path:'preview-evidence/home.png'});
  await page.getByRole('button',{name:'Personalise',exact:true}).click();
  await page.getByRole('button',{name:'Screensaver',exact:true}).click();
  await page.getByRole('button',{name:'Preview',exact:true}).click();
  await expect(page.getByText('Tap anywhere to return')).toBeVisible();
  await page.screenshot({path:'preview-evidence/screensaver.png'});
  await page.getByRole('button',{name:'Dismiss screensaver'}).click();
  await page.getByRole('button',{name:'Open Classroom',exact:true}).click();
  await page.getByRole('button',{name:'Full-page timer',exact:true}).first().click({timeout:60000});
  await expect(page.getByText('Classroom timer',{exact:true})).toBeVisible();
  await page.screenshot({path:'preview-evidence/timer.png'});
  await page.getByRole('button',{name:'Close timer'}).click();
  const studio = await context.newPage();
  await studio.goto(new URL('/teaching-studio/',base).href);
  await expect(studio.getByRole('heading',{name:'Teaching Studio',exact:true})).toBeVisible();
  await expect(studio.getByRole('button',{name:'Save board',exact:true})).toBeEnabled();
  await studio.screenshot({path:'preview-evidence/studio.png'});
  if (outside.some(h=>/googleapis|firebase|google\.com/i.test(h))) throw Error('Unexpected external cloud request: '+outside.join(', '));
  console.log('Verified hosted full application preview:',base);
} finally {
  await browser.close();
}
