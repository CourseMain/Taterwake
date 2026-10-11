// Rendered Web pixels, not material values. Run against the surfaces QA export.
// Example: node tests/test_vibrancy_browser.cjs http://127.0.0.1:8940 artifacts/vibrancy
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
(async()=>{
 const url=process.argv[2],out=process.argv[3];assert.ok(url&&out,'provide fixture URL and capture directory');fs.mkdirSync(out,{recursive:true});
 const browser=await chromium.launch({headless:true,executablePath:process.env.CHROME_EXECUTABLE||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',args:['--use-angle=metal']});
 const context=await browser.newContext({viewport:{width:1440,height:900},hasTouch:false});
 const page=await context.newPage(),errors=[];let report={};
 page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 async function present(key){
  const old=await page.evaluate(()=>window.surfaceReport.request);await page.evaluate(k=>window.surfaceQA(k),key);
  await page.waitForFunction(({old,key})=>window.surfaceReport?.ready&&window.surfaceReport.request>old&&window.surfaceReport.page===key,{old,key},{timeout:120000});
  await page.evaluate(()=>{window.surfaceQA('vibrancy:freeze');document.querySelector('#fullscreen-button')?.style.setProperty('visibility','hidden')});
  await page.waitForFunction(()=>window.surfaceReport?.vibrancy.paused);
  return page.evaluate(()=>window.surfaceReport);
 }
 async function capture(name){return (await page.screenshot({path:path.join(out,name)})).toString('base64')}
 try{
  await page.goto(url);await page.waitForFunction(()=>window.surfaceReport?.ready,null,{timeout:120000});
  const spring=await present('play_spring'),springPNG=await capture('spring-noon-hud-hidden-1440.png');
  const metrics=await page.evaluate(async({png,qa})=>{
   const image=new Image();image.src='data:image/png;base64,'+png;await image.decode();
   const canvas=document.createElement('canvas');canvas.width=image.width;canvas.height=image.height;const ctx=canvas.getContext('2d',{willReadFrequently:true});ctx.drawImage(image,0,0);
   const data=ctx.getImageData(0,0,canvas.width,canvas.height).data;
   const sx=canvas.width/qa.sun.viewport[0],sy=canvas.height/qa.sun.viewport[1];
   const mask=document.createElement('canvas');mask.width=canvas.width;mask.height=canvas.height;const mc=mask.getContext('2d',{willReadFrequently:true});
   mc.beginPath();qa.vibrancy.island_polygon.forEach(([x,y],i)=>i?mc.lineTo(x*sx,y*sy):mc.moveTo(x*sx,y*sy));mc.closePath();mc.fill();
   const land=mc.getImageData(0,0,mask.width,mask.height).data;let white=0,saturation=0,island=0;
   for(let i=0;i<data.length;i+=4){const r=data[i],g=data[i+1],b=data[i+2],max=Math.max(r,g,b),min=Math.min(r,g,b);if(r>=250&&g>=250&&b>=250)white++;if(land[i+3]===255){saturation+=max?(max-min)/max:0;island++}}
   // Mean displayed luminance of equal 5x5 ground patches. These coordinates
   // come from the three western orchard canopies. Their flat grass strip
   // contains no paths, buildings or beds; each lit patch sits beside its shade.
   function patch([x,y]){x=Math.round(x*sx);y=Math.round(y*sy);let sum=0,count=0;for(let dy=-2;dy<=2;dy++)for(let dx=-2;dx<=2;dx++){let i=((y+dy)*canvas.width+x+dx)*4;sum+=.2126*data[i]+.7152*data[i+1]+.0722*data[i+2];count++}return sum/count}
   const samples=qa.vibrancy.ground_samples.map(sample=>({...sample,shade_luminance:patch(sample.shade),lit_luminance:patch(sample.lit)}));
   samples.forEach(s=>s.ratio=s.shade_luminance/s.lit_luminance);
   return {white_pixels:white,pixels:canvas.width*canvas.height,white_fraction:white/(canvas.width*canvas.height),island_pixels:island,mean_island_saturation:saturation/island,ground_samples:samples,shade_ratio:samples.reduce((sum,s)=>sum+s.ratio,0)/samples.length};
  },{png:springPNG,qa:spring});
  await page.evaluate(()=>window.surfaceQA('vibrancy:resume'));
  const title=await present('title'),titlePNG=await capture('title-1440.png');
  await page.evaluate(()=>window.surfaceQA('vibrancy:hide_lettering'));
  const barePNG=await capture('title-lettering-mask-1440.png');
  const lettering=await page.evaluate(async({png,bare,qa})=>{
   async function pixels(src){const image=new Image();image.src='data:image/png;base64,'+src;await image.decode();const c=document.createElement('canvas');c.width=image.width;c.height=image.height;const cx=c.getContext('2d',{willReadFrequently:true});cx.drawImage(image,0,0);return cx.getImageData(0,0,c.width,c.height).data}
   const a=await pixels(png),b=await pixels(bare);const c=document.createElement('canvas');c.width=1440;c.height=900;const cx=c.getContext('2d',{willReadFrequently:true});cx.beginPath();qa.vibrancy.lettering_polygon.forEach(([x,y],i)=>i?cx.lineTo(x*1440/qa.sun.viewport[0],y*900/qa.sun.viewport[1]):cx.moveTo(x*1440/qa.sun.viewport[0],y*900/qa.sun.viewport[1]));cx.closePath();cx.fill();const mask=cx.getImageData(0,0,1440,900).data;
   let count=0,max=[0,0,0];for(let i=0;i<a.length;i+=4){if(mask[i+3]!==255||Math.max(Math.abs(a[i]-b[i]),Math.abs(a[i+1]-b[i+1]),Math.abs(a[i+2]-b[i+2]))<3)continue;count++;for(let k=0;k<3;k++)max[k]=Math.max(max[k],a[i+k])}return {pixels:count,max_channels:max};
  },{png:titlePNG,bare:barePNG,qa:title});
  report={spring:metrics,title_lettering:lettering,spring_fixture:spring.vibrancy,title_fixture:title.vibrancy,errors};
  report.gates={white:metrics.white_fraction<.005,saturation:metrics.mean_island_saturation>=.40&&metrics.mean_island_saturation<=.55,shade:metrics.ground_samples.every(s=>s.ratio>=.55&&s.ratio<=.70),title:lettering.pixels>100&&lettering.max_channels.every(c=>c<245)};
  console.log(JSON.stringify({spring:metrics,title_lettering:lettering,gates:report.gates},null,2));
  assert.equal(spring.vibrancy.hud_hidden,true);assert.equal(metrics.ground_samples.length,3);assert.ok(metrics.island_pixels>1440*900*.1, "island mask covers the rendered island");assert.equal(title.vibrancy.adjustment_enabled,false);assert.deepEqual(errors,[]);
  for(const [name,passed] of Object.entries(report.gates))assert.equal(passed,true,`${name} image gate`);
 }finally{fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2)+'\n');await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
