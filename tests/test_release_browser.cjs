const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
(async()=>{
 const root=(process.env.TATER_RELEASE_URL || 'http://127.0.0.1:8767/').replace(/(?:index\.html)?$/, '').replace(/\/?$/, '/');
 const output=process.env.TATER_RELEASE_OUTPUT || 'artifacts/update-browser/'+(process.env.TATER_RELEASE_URL?'github':'release');
 const expectedVersion=process.env.TATER_RELEASE_VERSION || '2.0.1';
 fs.mkdirSync(output,{recursive:true});
 const browser=await chromium.launch({headless:true,executablePath:process.env.CHROME_EXECUTABLE || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',args:['--use-angle=metal']});
 const results=[];
 try {
  for(const [path,version,name,width,height] of [['',expectedVersion,'redesign',1440,900],['',expectedVersion,'redesign',390,844],['classic/','1.0.3.1','classic',1280,800]].filter(row=>!process.env.TATER_RED_DESIGN_ONLY || row[2]==='redesign')){
   const context=await browser.newContext({viewport:{width,height},deviceScaleFactor:width===390?3:1,hasTouch:width===390,isMobile:width===390});
   const page=await context.newPage(),errors=[];
   page.on('pageerror',e=>errors.push(e.message));
   page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
   await page.goto(root+path+'index.html');
   assert.equal(await page.locator('meta[name="game-version"]').getAttribute('content'),version);
   await page.locator('#status').waitFor({state:'hidden',timeout:120000});
   await page.waitForTimeout(5000);
   assert.ok(await page.locator('#canvas').isVisible());
   const info=await page.evaluate(()=>({size:[document.querySelector('#canvas').width,document.querySelector('#canvas').height],qa:[typeof window.mobileQA,typeof window.mobileReport,typeof window.surfaceQA,typeof window.titleQA]}));
   assert.ok(info.qa.every(x=>x==='undefined'),'test fixtures excluded from both production games');
   await page.screenshot({path:output+'/'+name+'-title-'+width+'.png'});
   if(name==='redesign'){
    // A fresh title owns the screen and hides the shell controls until Walk.
    const canvas=await page.locator('#canvas').boundingBox();
    if(width===390)await page.touchscreen.tap(canvas.x+canvas.width/2,canvas.y+canvas.height*0.947);
    else await page.mouse.click(canvas.x+canvas.width/2,canvas.y+canvas.height*0.93);
    await page.waitForTimeout(3000);
    if(['2.0.2','2.0.3','2.0.4'].includes(version)){
     // Skip the new optional farmer card through its visible single exit.
     await page.screenshot({path:output+'/'+name+'-farmer-'+width+'.png'});
     const point=version==='2.0.4'
      ? (width===390?[.5,1002.4/1298]:[.5,631.5/800])
      : (width===390?[530/600,160/1298]:[1088/1440,153/900]);
     if(width===390)await page.touchscreen.tap(canvas.x+canvas.width*point[0],canvas.y+canvas.height*point[1]);
     else await page.mouse.click(canvas.x+canvas.width*point[0],canvas.y+canvas.height*point[1]);
     await page.waitForTimeout(1000);
    }
   }
   await page.locator('#fullscreen-button').waitFor({state:'visible',timeout:15000});
   if(width>=900){
    await page.locator('#fullscreen-button').click();
    assert.equal(await page.evaluate(()=>!!document.fullscreenElement),true);
    await page.locator('#fullscreen-button').click();
    assert.equal(await page.evaluate(()=>!!document.fullscreenElement),false);
   }
   await page.screenshot({path:output+'/'+name+'-'+width+'.png'});
   assert.deepEqual(errors,[]);
   results.push({name,version,resolution:[width,height],url:page.url(),...info,fullscreen:width>=900,errors});
   console.log(name+' '+version+' '+width+'x'+height+': production entry passed; no fixture bridge or browser errors');
   await context.close();
  }
 } finally {fs.writeFileSync(output+'/report.json',JSON.stringify({results},null,2)+'\n');await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
