import {chromium} from '@playwright/test';
import {spawn} from 'node:child_process';
import assert from 'node:assert/strict';
import {mkdir} from 'node:fs/promises';
const server=spawn(process.execPath,['staging-tests/serve-complete-app.mjs'],{stdio:'inherit'});
let browser;
try{
 for(let i=0;i<50;i++){
  try{const r=await fetch('http://127.0.0.1:7357/');if(r.ok)break;}catch{}
  await new Promise(r=>setTimeout(r,100));
 }
 const raw=process.env.HTTPS_PROXY??process.env.HTTP_PROXY;const proxy=raw?new URL(raw):null;
 if(proxy)process.env.PLAYWRIGHT_DISABLE_FORCED_CHROMIUM_PROXIED_LOOPBACK='1';
 browser=await chromium.launch({proxy:proxy?{server:proxy.origin,username:decodeURIComponent(proxy.username),password:decodeURIComponent(proxy.password),bypass:'localhost,127.0.0.1'}:undefined});
 const page=await browser.newPage();const errors=[],production=[];
 page.on('pageerror',e=>{errors.push(e.message);console.log('BROWSER_ERROR',e.message);});
 page.on('console',m=>{if(m.type()==='error')console.log('BROWSER_CONSOLE',m.text());});
 page.on('requestfailed',r=>console.log('REQUEST_FAILED',new URL(r.url()).host,new URL(r.url()).pathname,r.failure()?.errorText));
 await page.route('**/*',async route=>{
  const host=new URL(route.request().url()).hostname;
  if(['firestore.googleapis.com','identitytoolkit.googleapis.com','securetoken.googleapis.com'].includes(host)||host.endsWith('cloudfunctions.net')){production.push(host);return route.abort();}
  return route.continue();
 });
 await page.goto('http://127.0.0.1:7357/');
 await page.waitForTimeout(6000);
 console.log('ACCEPTANCE_STATE',await page.locator('body').innerText());
 await mkdir('test-results/communication-security',{recursive:true});
 await page.screenshot({path:'test-results/communication-security/sdk.png'});
 await page.getByText(/^(PASS all 3|FAIL) communication SDK acceptance|^Blocked:/).waitFor({timeout:90000});
 const result=await page.locator('body').innerText();console.log(result);
 assert.match(result,/PASS all 3 communication SDK acceptance groups/);
 assert.deepEqual(errors,[]);assert.deepEqual(production,[]);
 console.log('Actual Flutter Firebase repository acceptance passed; no production data endpoints contacted.');
}finally{if(browser)await browser.close();server.kill('SIGTERM');}
