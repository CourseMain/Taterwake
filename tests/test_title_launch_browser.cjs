// Observe the real Main launch/save path, including its first farm draw.
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const url=process.argv[2]||'http://127.0.0.1:8933/index.html';
const output=process.argv[3]||'artifacts/v2.0.1-title-web';
const repetitions=3;
function fit(s){
 assert.ok(Math.abs(s.camera_size-s.overview_size)<0.01,'camera fits current overview');
 assert.ok(Math.abs(s.home_size-s.overview_size)<0.01,'Home fits current overview');
 assert.ok(s.camera_home_distance<0.01,'pan starts at the fitted overview');
 const [x,y,w,h]=s.island.bounds;
 assert.ok(w>=0.55 && h>=0.12,'island fills the overview instead of shrinking');
 assert.ok(x>=0 && y>=0 && x+w<=1 && y+h<=1,'island stays inside the frame');
 assert.equal(s.island.clipped,false,'island lies within the camera depth');
}
(async()=>{
 fs.mkdirSync(output,{recursive:true});
 const browser=await chromium.launch({headless:true,executablePath:process.env.CHROME_EXECUTABLE||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',args:['--use-angle=metal']});
 const results=[],errors=[];
 try{
  for(const [width,height] of [[1440,900],[390,844]]){
   for(let attempt=0;attempt<repetitions;attempt++){
    const context=await browser.newContext({viewport:{width,height},hasTouch:true,isMobile:width<900});
    const page=await context.newPage();
    page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
    const state=()=>page.evaluate(()=>{window.titleQA('status');return window.titleReport.state});
    const launch=async()=>{await page.goto(url);await page.waitForFunction(()=>window.titleReport?.ready,null,{timeout:120000});return page.evaluate(()=>window.titleReport.first_frame)};
    const tap=async key=>{await page.waitForTimeout(100);const s=await state(),r=s[key],canvas=await page.locator('#canvas').boundingBox();await page.touchscreen.tap(canvas.x+(r[0]+r[2]/2)*canvas.width/s.logical_size[0],canvas.y+(r[1]+r[3]/2)*canvas.height/s.logical_size[1]);};
    const wait=predicate=>page.waitForFunction(predicate=>{window.titleQA('status');return new Function('s',`return (${predicate})`)(window.titleReport.state)},predicate,{timeout:15000});
    const fresh=await launch();
    assert.equal(fresh.test_mode,false);assert.equal(fresh.title,true);assert.equal(fresh.hud,false);assert.equal(fresh.panel,false);assert.equal(fresh.front_page,false);assert.equal(fresh.guide,'');assert.equal(fresh.primary,'Walk to the farm');assert.equal(fresh.secondary_visible,false);
    assert.equal(fresh.idle.poses.length,3);assert.equal(fresh.idle.petals,6);
    if(attempt===1)await page.waitForTimeout(8500); // also enter after the pullback
    if(attempt===2){await page.setViewportSize({width:width===390?844:900,height:height===844?390:1440});await page.waitForTimeout(250);await page.setViewportSize({width,height});await page.waitForTimeout(250);}
    if(attempt===0)await page.screenshot({path:`${output}/title-${width}.png`});
    await tap('primary_rect');await wait('!s.title && s.guide==="welcome"');
    await page.waitForFunction(()=>window.titleReport.first_farm_frame && Object.keys(window.titleReport.first_farm_frame).length,null,{timeout:15000});
    const firstFarm=await page.evaluate(()=>window.titleReport.first_farm_frame);fit(firstFarm);
    assert.equal(firstFarm.front_page,false);assert.equal(firstFarm.idle.petals,0);assert.equal(firstFarm.idle.poses.length,0);
    await page.waitForTimeout(300);fit(await state());
    if(attempt===0)await page.screenshot({path:`${output}/farm-${width}.png`});
    results.push({resolution:[width,height],attempt,first_farm_frame:firstFarm});
    if(attempt===0){
     await page.evaluate(()=>window.titleQA('checkpoint'));await page.waitForTimeout(3000);
     const returning=await launch();assert.equal(returning.saved,true);assert.equal(returning.title,true);assert.equal(returning.hud,false);assert.equal(returning.panel,false);assert.equal(returning.guide,'');assert.equal(returning.primary,'Continue · Year 1, Spring');assert.equal(returning.secondary_visible,true);
     await tap('secondary_rect');await wait('s.confirmation && s.keep_rect[0]>0 && s.keep_rect[1]>0');const confirmation=await state();assert.equal(confirmation.safe_default,true);assert.equal(confirmation.pause_reset,false);assert.equal(confirmation.hud,false);assert.equal(confirmation.panel,false);
     await tap('keep_rect');await wait('!s.confirmation');await tap('primary_rect');await wait('!s.title');assert.equal((await state()).panel,false);assert.equal((await state()).guide,'welcome');
    }
    await context.close();
    console.log(`TITLE WEB: ${width}x${height} fresh launch ${attempt+1}: first farm draw and stable overview pass`);
   }
  }
  assert.deepEqual(errors,[]);
 }finally{fs.writeFileSync(output+'/report.json',JSON.stringify({url,repetitions,results,errors},null,2)+'\n');await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
