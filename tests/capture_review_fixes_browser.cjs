const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
(async()=>{
 const out=process.argv[3];fs.mkdirSync(out,{recursive:true});
 const browser=await chromium.launch({headless:true,executablePath:process.env.CHROME_EXECUTABLE||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',args:['--use-angle=metal']});
 const reports=[],errors=[];
 try {
  for(const [width,height,touch] of [[390,844,true],[1440,900,false]]){
   const context=await browser.newContext({viewport:{width,height},hasTouch:touch,isMobile:touch});
   const page=await context.newPage();page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
   await page.goto(process.argv[2]);await page.waitForFunction(()=>window.surfaceReport?.ready,null,{timeout:120000});
   for(const key of (process.env.REVIEW_PAGES||'station_noon,station_dusk,tools,decorations,grades,accounts,market,play_winter,play_spring,play_summer,play_autumn,guide_welcome').split(',')){
    const old=await page.evaluate(()=>window.surfaceReport.request);await page.evaluate(k=>window.surfaceQA(k),key);
    await page.waitForFunction(({old,key})=>window.surfaceReport?.ready&&window.surfaceReport.request>old&&window.surfaceReport.page===key,{old,key},{timeout:120000});
    const report=await page.evaluate(()=>window.surfaceReport);
    assert.equal(report.content_fits_width,true,`${key} fits ${width}`);
    if(report.panel_kind){const [x,y,w,h]=report.modal;assert.ok(x>=0&&x+w<=report.logical_size[0]+1,`${key} card stays within ${width}`);assert.ok(y>=0&&y+h<=report.logical_size[1]+1,`${key} card stays within height`);}
    if(key==='grades')assert.ok(Math.abs(report.modal[3]-report.modal_content_height)<2,'grades card fits content');
    if(key==='accounts'){
     const tiles=report.buttons.filter(b=>['Records','Field leases','Farm businesses'].includes(b.text));assert.equal(tiles.length,3);assert.ok(tiles.every(b=>b.drawn&&Object.keys(b.picture).length&&Math.abs(b.rect[1]-tiles[0].rect[1])<1),'account detail drawings share one row');
    }
    if(key==='market'){
     assert.ok(!report.labels.some(l=>l.text.startsWith('1 seasons')));assert.ok(report.labels.some(l=>l.text.startsWith('1 season ·')));
     assert.ok(report.labels.filter(l=>['Thirst','Heat','Cold'].includes(l.text)).every(l=>l.font_size*width/report.logical_size[0]>=14),'seed trait text is fourteen CSS pixels');
    }
    if(key==='play_winter'&&touch){
     const season=report.buttons.find(b=>b.text==='Winter · Year 3'), money=report.labels.find(l=>/^-?[0-9,]+$/.test(l.text));assert.ok(season&&money&&season.rect[1]+season.rect[3]<=money.rect[1],'Winter year and money have separate phone rows');
    }
    if(key.startsWith('guide_')){
     assert.ok(Object.values(report.guide_icons).every(v=>!v),'guide hides the extra controls');assert.equal(await page.locator('#fullscreen-button').evaluate(b=>getComputedStyle(b).visibility),'hidden');
    }
    await page.screenshot({path:`${out}/${key}-${width}.png`});reports.push({...report,capture:`${key}-${width}.png`,css_size:[width,height]});
    if(key==='decorations'){
     await page.evaluate(()=>window.surfaceQA('scroll:end'));
     await page.waitForFunction(()=>window.surfaceReport?.ready,null,{timeout:120000});
     await page.screenshot({path:`${out}/decorations-end-${width}.png`});
     reports.push({...await page.evaluate(()=>window.surfaceReport),capture:`decorations-end-${width}.png`,css_size:[width,height]});
    }
   }
   await context.close();
  }
  assert.deepEqual(errors,[]);
 }finally{fs.writeFileSync(out+'/report.json',JSON.stringify({reports,errors},null,2)+'\n');await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
