// Disposable title_launch export uses the production launch/save path.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const url=process.argv[2] || 'http://127.0.0.1:8933/index.html';
const output=process.argv[3] || 'artifacts/n-title-launch.json';
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.CHROME_EXECUTABLE || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',args:['--use-angle=metal']});
 const context=await browser.newContext({viewport:{width:390,height:844},hasTouch:true,isMobile:true});
 const page=await context.newPage(),errors=[],results=[];
 page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 const state=async()=>await page.evaluate(()=>{window.titleQA('status');return window.titleReport.state});
 const tap=async key=>{const s=await state(),r=s[key],canvas=await page.locator('#canvas').boundingBox();await page.touchscreen.tap(canvas.x+(r[0]+r[2]/2)*canvas.width/s.logical_size[0],canvas.y+(r[1]+r[3]/2)*canvas.height/s.logical_size[1]);};
 const wait=async predicate=>page.waitForFunction(predicate=>{window.titleQA('status');return new Function('s',`return (${predicate})`)(window.titleReport.state)},predicate,{timeout:15000});
 const launch=async()=>{await page.goto(url);await page.waitForFunction(()=>window.titleReport?.ready,null,{timeout:120000});return await page.evaluate(()=>window.titleReport.first_frame)};
 try{
  const fresh=await launch();assert.equal(fresh.test_mode,false);assert.equal(fresh.title,true);assert.equal(fresh.hud,false);assert.equal(fresh.panel,false);assert.equal(fresh.front_page,false);assert.equal(fresh.guide,'');assert.equal(fresh.primary,'Walk to the farm');assert.equal(fresh.secondary_visible,false);
  await page.screenshot({path:'docs/style-board/tag-n-title-fresh-390.png'});results.push({state:'fresh first game render',...fresh});
  await tap('primary_rect');await page.waitForFunction(()=>{window.titleQA('status');return !window.titleReport.state.title&&window.titleReport.state.guide==='welcome'},null,{timeout:15000});assert.equal((await state()).front_page,false);results.push({state:'after walk',...await state()});
  await page.evaluate(()=>window.titleQA('checkpoint'));await page.waitForTimeout(3000);
  const returning=await launch();assert.equal(returning.saved,true);assert.equal(returning.title,true);assert.equal(returning.hud,false);assert.equal(returning.panel,false);assert.equal(returning.guide,'');assert.equal(returning.primary,'Continue · Year 1, Spring');assert.equal(returning.secondary_visible,true);
  await page.screenshot({path:'docs/style-board/tag-n-title-returning-390.png'});results.push({state:'saved first game render',...returning});
  await tap('secondary_rect');await wait('s.confirmation');const confirm=await state();assert.equal(confirm.confirmation,true);assert.equal(confirm.safe_default,true);assert.equal(confirm.pause_reset,false);assert.equal(confirm.hud,false);assert.equal(confirm.panel,false);
  await page.screenshot({path:'docs/style-board/tag-n-title-replace-390.png'});results.push({state:'title replacement confirmation',...confirm});
  await tap('keep_rect');await wait('!s.confirmation');assert.equal((await state()).confirmation,false);await tap('primary_rect');await wait('!s.title');assert.equal((await state()).title,false);assert.equal((await state()).panel,false);results.push({state:'resumed farm',...await state()});
  assert.deepEqual(errors,[]);console.log('TITLE WEB: fresh first render, walk-in guide, persistent relaunch, safe replacement and direct Continue pass');
 }finally{fs.writeFileSync(output,JSON.stringify({url,resolution:[390,844],results,errors},null,2)+'\n');await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
