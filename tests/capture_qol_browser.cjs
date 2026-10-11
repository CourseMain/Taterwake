const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
(async()=>{
 const [url,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
 const browser=await chromium.launch({headless:true,executablePath:process.env.CHROME_EXECUTABLE||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',args:['--use-angle=metal']});
 const reports=[],errors=[];
 try{
  for(const [width,height,views] of [[1440,900,['qol_home','qol_low','qol_quests:0','qol_quests:1','qol_quests:2','qol_quests:3']],[390,844,['qol_rent','qol_locked','qol_winter','qol_grades','qol_accounts','qol_seed','qol_guide','qol_refused','qol_undo']]]){
   const context=await browser.newContext({viewport:{width,height},hasTouch:width===390,isMobile:width===390});
   const page=await context.newPage();page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
   await page.goto(url);await page.waitForFunction(()=>window.surfaceReport?.ready,null,{timeout:120000});
   for(const key of views.filter(key=>!process.env.QOL_VIEWS||process.env.QOL_VIEWS.split(',').includes(key))){
    const old=await page.evaluate(()=>window.surfaceReport.request);
    await page.evaluate(key=>window.surfaceQA(key),key);
    await page.waitForFunction(({old,key})=>window.surfaceReport?.ready&&window.surfaceReport.request>old&&window.surfaceReport.page===key.split(':')[0],{old,key},{timeout:120000});
    const capture=key.replace(':','-')+'-'+width+'.png';
    await page.screenshot({path:out+'/'+capture});reports.push({...await page.evaluate(()=>window.surfaceReport),capture,css_size:[width,height]});
    console.log('Captured',key,width+'x'+height);
   }
   await context.close();
  }
  assert.deepEqual(errors,[]);
 }finally{fs.writeFileSync(out+'/report.json',JSON.stringify({reports,errors},null,2)+'\n');await browser.close();}
})().catch(error=>{console.error(error);process.exit(1)});
