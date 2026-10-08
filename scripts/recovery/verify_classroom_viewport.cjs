const {chromium}=require('playwright');
const fs=require('fs');
const path=require('path');
const output=process.env.RECOVERY_CAPTURE_DIR || path.join(process.cwd(),'build','recovery-viewport');
fs.mkdirSync(output,{recursive:true});
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH,headless:true});
 const page=await browser.newPage({viewport:{width:1366,height:768}});
 if(process.env.RECOVERY_ROBOTO_PATH) await page.route('https://fonts.gstatic.com/s/roboto/**', route => route.fulfill({path:process.env.RECOVERY_ROBOTO_PATH,contentType:'font/ttf'}));
 const errors=[];page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 await page.goto(process.env.CLASSROOM_PREVIEW_URL || 'http://127.0.0.1:8770/',{waitUntil:'networkidle'});
 await page.waitForFunction(()=>document.querySelector('flt-semantics-placeholder'));
 await page.locator('flt-semantics-placeholder').evaluate(el=>el.click());
 await page.getByRole('button',{name:'Start class',exact:true}).click();
 await page.waitForTimeout(800);
 const prefix=process.argv[2]||'viewport';
 await page.mouse.move(0,0);await page.waitForTimeout(400);
 const checkRoom = async (minY=94,maxY=686) => {
   const tableRects=[];
   for(let n=1;n<=6;n++) {
     const r=await page.getByText(`TABLE ${n}`,{exact:true}).boundingBox();
     if(!r || r.y<minY || r.y+r.height>maxY) throw new Error(`Table ${n} outside classroom viewport: ${JSON.stringify(r)}`);
     tableRects.push(r);
   }
   for(let col=0;col<3;col++) {
     if(Math.abs(tableRects[col].y-tableRects[0].y)>1 || Math.abs(tableRects[col+3].y-tableRects[3].y)>1 || Math.abs(tableRects[col].x-tableRects[col+3].x)>1) throw new Error('Six-table alignment changed');
   }
   const seatRects=[];
   for(const [i,name] of ['Alex','Bella','Charlie','Dara','Eli','Freya','George','Hana','Isaac','Jules','Kai','Lena'].entries()) {
     const seat=page.getByRole('button',{name:`${String(i+1).padStart(2,'0')} ${name}`,exact:true});
     const r=await seat.boundingBox();
     if(!r || r.y<minY || r.y+r.height>maxY) throw new Error(`${name} outside classroom viewport: ${JSON.stringify(r)}`);
     seatRects.push({name,...r});
   }
   return {tableRects,seatRects};
 };
 const light=await checkRoom();
 await page.screenshot({path:`${output}/${prefix}-normal-light.png`});
 await page.getByRole('button',{name:'Dark mode',exact:true}).click();await page.waitForTimeout(400);
 await page.mouse.move(0,0);await page.waitForTimeout(400);
 const dark=await checkRoom();
 fs.writeFileSync(`${output}/${prefix}-bounds.json`,JSON.stringify({light,dark},null,2));
 await page.screenshot({path:`${output}/${prefix}-normal-dark.png`});
 await page.getByRole('checkbox',{name:'Present',exact:true}).click();await page.waitForTimeout(500);
 await page.mouse.move(0,0);await page.waitForTimeout(400);
 await checkRoom(60,720);
 await page.screenshot({path:`${output}/${prefix}-presentation-dark.png`});
 await page.getByRole('button',{name:'Light mode',exact:true}).click();await page.waitForTimeout(400);
 await page.mouse.move(0,0);await page.waitForTimeout(400);
 await checkRoom(60,720);
 await page.screenshot({path:`${output}/${prefix}-presentation-light.png`});
 fs.writeFileSync(`${output}/${prefix}-browser-errors.json`,JSON.stringify(errors,null,2));
 console.log('PASS: six-table alignment and all 12 student targets fit in both themes and modes at 1366x768, without scrolling.');
 console.log('Captured four preview states; errors:',errors);await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
