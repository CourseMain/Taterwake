const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
(async()=>{
 const [url,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
 const browser=await chromium.launch({headless:true,executablePath:process.env.CHROME_EXECUTABLE||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',args:['--use-angle=metal']});
 const errors=[],reports=[];
 try {
  const context=await browser.newContext({viewport:{width:390,height:844},hasTouch:true,isMobile:true});
  const page=await context.newPage();page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR:|ERROR:/.test(m.text()))errors.push(m.text())});
  await page.goto(url);await page.waitForFunction(()=>window.surfaceReport?.ready,null,{timeout:120000});
  for(const view of ['pedlar_passing','pedlar_parked','pedlar_page','pedlar_odds','pedlar_windup','pedlar_result','pedlar_gate','pedlar_collection','pedlar_farmer','pedlar_refused','pedlar_blue_sell']) {
   const old=await page.evaluate(()=>window.surfaceReport.request);
   await page.evaluate(view=>window.surfaceQA(view),view);
   await page.waitForFunction(({old,view})=>window.surfaceReport?.ready&&window.surfaceReport.request>old&&window.surfaceReport.page===view,{old,view},{timeout:120000});
   const report=await page.evaluate(()=>window.surfaceReport);
   if(view==='pedlar_passing')assert.equal(report.pedlar.target_layer,0);
   if(view==='pedlar_parked')assert.equal(report.pedlar.target_layer,1);
   if(view==='pedlar_windup')assert(report.pedlar.revealing&&!report.pedlar.result_visible);
   if(view==='pedlar_result')assert(report.pedlar.result_visible&&!report.pedlar.revealing);
   if(view==='pedlar_gate')assert.equal(report.pedlar.hooks[0],'Second Sowing');
   if(view==='pedlar_blue_sell')assert(report.labels.some(label=>label.text.startsWith('Blue Pearl')));
   const capture=view.replace('pedlar_','')+'-390.png';
   await page.screenshot({path:out+'/'+capture});reports.push({...report,capture});console.log('Captured',capture);
  }
  assert.deepEqual(errors,[]);
 } finally {fs.writeFileSync(out+'/browser-report.json',JSON.stringify({reports,errors},null,2)+'\n');await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
