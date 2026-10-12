const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
(async()=>{
 const [url,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
 const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',args:['--use-angle=metal']});
 const results=[],errors=[];
 try{
  for(const [width,height] of [[390,844],[1440,900]]){
   const context=await browser.newContext({viewport:{width,height},hasTouch:width===390,isMobile:width===390});
   const page=await context.newPage();page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR:|ERROR:/.test(m.text()))errors.push(m.text())});
   await page.goto(url);await page.waitForFunction(()=>window.surfaceReport?.ready,null,{timeout:120000});
   const old=await page.evaluate(()=>window.surfaceReport.request);
   await page.evaluate(()=>window.surfaceQA('qol_player'));
   await page.waitForFunction(old=>window.surfaceReport?.ready&&window.surfaceReport.request>old&&window.surfaceReport.page==='qol_player',old);
   async function status(name){
    await page.evaluate(()=>window.surfaceQA('status'));
    const camera=await page.evaluate(()=>window.surfaceReport.player_camera);
    const error=Math.hypot(camera.body_screen[0]-camera.viewport[0]/2,camera.body_screen[1]-camera.viewport[1]/2);
    assert(error<.02,`${width} ${name}: player centre error ${error} px`);
    results.push({size:[width,height],step:name,...camera,centre_error_px:error});return camera;
   }
   const initial=await status('idle');await page.screenshot({path:`${out}/player-idle-${width}.png`});
   await page.keyboard.down('d');await page.waitForTimeout(500);await page.keyboard.up('d');
   const walking=await status('walk');assert(Math.hypot(...walking.player.map((v,i)=>v-initial.player[i]))>1,'real keyboard movement moves the farmer');
   await page.screenshot({path:`${out}/player-walk-${width}.png`});
   await page.mouse.move(width/2,height/2);await page.mouse.wheel(0,-180);await page.waitForTimeout(500);
   const zoom=await status('scroll');assert(zoom.size<walking.size,'real wheel scrolling zooms the locked view');
   await page.screenshot({path:`${out}/player-zoom-${width}.png`});
   await page.mouse.down();await page.mouse.move(width/2+80,height/2+40,{steps:8});await page.mouse.up();
   await status('drag');await context.close();
  }
  assert.deepEqual(errors,[]);console.log('PLAYER CAMERA WEB: 8 centred states, 2 movement checks, 2 scroll checks, 0 failures');
 }finally{fs.writeFileSync(out+'/camera.json',JSON.stringify({results,errors},null,2)+'\n');await browser.close()}
})().catch(error=>{console.error(error);process.exit(1)});
