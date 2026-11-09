const {chromium}=require('playwright');
const assert=require('assert');
(async()=>{
 const b=await chromium.launch();
 for(const size of [{width:1920,height:1080},{width:2880,height:1500}]){
  const c=await b.newContext({viewport:size});const p=await c.newPage();
  await p.goto(process.env.REVIEW_URL||'http://127.0.0.1:7358/#/preview/classroom');
  await p.waitForTimeout(6000);await p.locator('flt-semantics-placeholder').evaluate(e=>e.click()).catch(()=>{});
  await p.getByRole('button',{name:'Arrange room',exact:true}).click();
  await p.getByRole('button',{name:'Close tools',exact:true}).click();await p.waitForTimeout(500);
  const read=()=>p.evaluate(()=>JSON.parse(JSON.parse(localStorage.getItem('flutter.seating_layouts_synthetic-public-classroom-preview')))[0]);
  const before=await read();
  const table=p.getByText('Table',{exact:true}).first();
  for(const edge of ['left','right','top','bottom']){
   const r=await table.boundingBox();assert(r);const x=r.x+r.width/2,y=r.y+r.height/2;
   await p.mouse.move(x,y);await p.mouse.down();
   await p.mouse.move(edge==='left'?-3000:edge==='right'?6000:x,edge==='top'?-3000:edge==='bottom'?6000:y,{steps:10});
   await p.mouse.up();await p.waitForTimeout(350);
   const l=await read(),t=l.tables[0];
   if(edge==='left') assert(Math.abs(t.x-t.width/2)<.01,'left wall');
   if(edge==='right') {assert(t.x>1200,'must move beyond original width');assert(Math.abs(t.x+t.width/2-l.canvasWidth)<.01,'right wall');}
   if(edge==='top') assert(Math.abs(t.y-t.height/2)<.01,'top wall');
   if(edge==='bottom') assert(t.y>before.tables[0].y && t.y+t.height/2<=l.canvasHeight+.01,'bottom reach');
   assert.deepStrictEqual(l.seats,before.seats,'seat metadata retained');
   await p.getByRole('button',{name:'Undo',exact:true}).click();await p.waitForTimeout(200);
  }
  await p.screenshot({path:`../full-canvas-${size.width}.png`});
  console.log(`ALL FOUR EDGES PASS ${size.width}x${size.height}`);await c.close();
 }
 await b.close();
})().catch(e=>{console.error(e);process.exit(1)});

