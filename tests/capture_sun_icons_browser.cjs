// Six Web play views, real icon targets, plus paired sun-shadow measurements.
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const url=process.argv[2]||'http://127.0.0.1:8943/index.html';
const out=process.argv[3]||'artifacts/v2.0.3-sun-review';
fs.mkdirSync(out,{recursive:true});
let activeBrowser;
(async()=>{
 const browser=activeBrowser=await chromium.launch({headless:true,executablePath:process.env.CHROME_EXECUTABLE,args:process.platform==='darwin'?['--use-angle=metal']:[]});
 const reports=[], errors=[], shadeFailures=[];
 for(const [width,height,touch] of [[1440,900,false],[390,844,true]]){
  const context=await browser.newContext({viewport:{width,height},hasTouch:touch,deviceScaleFactor:1});
  const page=await context.newPage();
  page.on('pageerror',e=>errors.push(`${width}: ${e.message}`));
  page.on('console',m=>{if(m.type()==='error'&&!m.text().includes('favicon'))errors.push(`${width}: ${m.text()}`)});
  await page.goto(url,{waitUntil:'domcontentloaded',timeout:120000});
  await page.waitForFunction(()=>window.surfaceQA&&window.surfaceReport?.ready,null,{timeout:120000});
  const command=async key=>{
   const old=await page.evaluate(()=>window.surfaceReport.request);
   await page.evaluate(key=>window.surfaceQA(key),key);
   await page.waitForFunction(({key,old})=>window.surfaceReport?.ready&&(key.startsWith('sun_probe:')||window.surfaceReport.request>old),{key,old},{timeout:120000});
   return page.evaluate(()=>window.surfaceReport);
  };
  const pixel=async(report,buffer)=>{
   const px=report.sun.probe_pixel[0]/report.sun.viewport[0]*width;
   const py=report.sun.probe_pixel[1]/report.sun.viewport[1]*height;
   assert.ok(px>2&&py>2&&px<width-2&&py<height-2,'probe is visible');
   return page.evaluate(async({data,px,py})=>{
    const img=new Image();img.src='data:image/png;base64,'+data;await img.decode();
    const c=new OffscreenCanvas(img.width,img.height),ctx=c.getContext('2d');ctx.drawImage(img,0,0);
    const rgba=ctx.getImageData(Math.round(px)-1,Math.round(py)-1,3,3).data;
    let rgb=[0,0,0];for(let i=0;i<rgba.length;i+=4)for(let k=0;k<3;k++)rgb[k]+=rgba[i+k]/9;
    return rgb;
   },{data:buffer.toString('base64'),px,py});
  };
  for(const season of ['spring','summer','autumn']){
   const report=await command('play_'+season);
   const buttons=['Weather','Menu'].map(text=>report.buttons.find(b=>b.text===text));
   buttons.forEach(b=>assert.ok(b?.drawn,'real icon above '+b?.text));
   const full=await page.locator('#fullscreen-button').boundingBox();
   assert.ok(full.x<12&&full.y<12&&full.width===44,'fullscreen is top left');
   const scale=width/report.logical_size[0];
   buttons.forEach(b=>assert.ok(b.font_size*scale>=13.99,'readable caption'));
   assert.ok(Math.abs(report.sun.opacity-.85)<1e-5,'85% shadow opacity');
   const capture=`${season}-${width}.png`;
   await page.screenshot({path:path.join(out,capture),timeout:60000});
   reports.push({...report,capture,css_size:[width,height]});
   // Same surface and pixel, with only a test occluder toggled. Does not
   // compare different terrain colours, decorative contact patches or beds.
   const clear=await command('sun_probe:clear');
   const lit=await pixel(clear,await page.screenshot({timeout:60000}));
   const shadow=await command('sun_probe:shadow');
   const shade=await pixel(shadow,await page.screenshot({timeout:60000}));
   const brightness=c=>.2126*c[0]+.7152*c[1]+.0722*c[2];
   const ratio=brightness(shade)/brightness(lit);
   reports.push({measurement:season,width,lit,shade,ratio});
   console.log('SHADE',season,width,ratio,lit,shade);
   if(ratio<.59||ratio>.71)shadeFailures.push(`${season} ${width}: ${ratio}`);
  }
  await command('play_autumn');
  const winter=await command('sun_probe:winter');
  const lit=await pixel(winter,await page.screenshot({timeout:60000}));
  const shadow=await command('sun_probe:shadow');
  const shade=await pixel(shadow,await page.screenshot({timeout:60000}));
  const brightness=c=>.2126*c[0]+.7152*c[1]+.0722*c[2];
  const ratio=brightness(shade)/brightness(lit);
  reports.push({measurement:'winter',width,lit,shade,ratio});
  console.log('SHADE winter',width,ratio,lit,shade);
  if(ratio<.59||ratio>.71)shadeFailures.push(`winter ${width}: ${ratio}`);
  await context.close();
 }
 assert.deepEqual(errors,[]);
 fs.writeFileSync(path.join(out,'report.json'),JSON.stringify({reports,errors},null,2)+'\n');
 assert.deepEqual(shadeFailures,[],'shade is about 60–70% as bright in every season');
 console.log('SUN WEB: six captures and eight paired shade measurements passed');
 await browser.close();
})().catch(async e=>{console.error(e);await activeBrowser?.close();process.exitCode=1});
