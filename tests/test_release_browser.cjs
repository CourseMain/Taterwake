const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
(async()=>{
 const root=(process.env.TATER_RELEASE_URL || 'http://127.0.0.1:8767/').replace(/(?:index\.html)?$/, '').replace(/\/?$/, '/');
 const output='artifacts/update-browser/'+(process.env.TATER_RELEASE_URL?'github':'release');
 fs.mkdirSync(output,{recursive:true});
 const browser=await chromium.launch({headless:true,executablePath:process.env.CHROME_EXECUTABLE || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',args:['--use-angle=metal']});
 const results=[];
 try {
  for(const [path,version,name] of [['','2.0.0','redesign'],['classic/','1.0.3.1','classic']]){
   const context=await browser.newContext({viewport:{width:1280,height:800}});
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
   await page.screenshot({path:output+'/'+name+'-title-1280.png'});
   if(name==='redesign'){
    // A fresh title owns the screen and hides the shell controls until Walk.
    const canvas=await page.locator('#canvas').boundingBox();
    await page.mouse.click(canvas.x+canvas.width/2,canvas.y+canvas.height*0.93);
    await page.waitForTimeout(3000);
   }
   await page.locator('#fullscreen-button').click();
   assert.equal(await page.evaluate(()=>!!document.fullscreenElement),true);
   await page.locator('#fullscreen-button').click();
   assert.equal(await page.evaluate(()=>!!document.fullscreenElement),false);
   await page.screenshot({path:output+'/'+name+'-1280.png'});
   assert.deepEqual(errors,[]);
   results.push({name,version,url:page.url(),...info,fullscreen:true,errors});
   console.log(name+' '+version+': production load and fullscreen passed; no fixture bridge or browser errors');
   await context.close();
  }
 } finally {fs.writeFileSync(output+'/report.json',JSON.stringify({results},null,2)+'\n');await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
