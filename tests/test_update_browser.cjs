// Disposable browser fixture only; never opens a player save.
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
fs.mkdirSync('artifacts/update-browser',{recursive:true});
(async()=>{
 const browser=await chromium.launch({headless:true});
 const errors=[];
 for(const [name,width,height,touch] of [['desktop',1280,800,false],['phone',390,844,true]]){
  const context=await browser.newContext({viewport:{width,height},hasTouch:touch,deviceScaleFactor:1});
  const page=await context.newPage();
  page.on('pageerror',e=>errors.push(name+': '+e.message));
  page.on('console',m=>{if(m.type()==='error')errors.push(name+': '+m.text())});
  await page.goto(process.env.TATER_QA_URL || 'http://127.0.0.1:8766/index.html');
  await page.waitForFunction(()=>!!window.mobileQA,null,{timeout:60000});
  const report=()=>page.evaluate(()=>{window.mobileQA('status');return window.mobileReport});
  const command=async action=>{await page.evaluate(a=>window.mobileQA(a),action);await page.waitForTimeout(300);return report()};
  assert.equal((await report()).version,'1.0.3.1');
  const screenshot=async suffix=>page.screenshot({path:`artifacts/update-browser/${name}-${suffix}.png`});
  await command('layout:1');
  await screenshot('valley');
  const initial=await report();
  const x=width*.47,y=height*.46;
  // Sparse drag events must still produce motion on intervening rendered frames.
  await page.evaluate(()=>{window.panFrames=[];window.samplePan=true;function sample(){if(!window.samplePan)return;window.mobileQA('status');window.panFrames.push(window.mobileReport.camera.slice());requestAnimationFrame(sample)}requestAnimationFrame(sample)});
  if(touch){
   const cdp=await context.newCDPSession(page);
   await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:1,x,y}]});
   for(let i=1;i<=5;i++){await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:1,x:x+i*12,y:y+i*5}]});await page.waitForTimeout(65)}
   await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
  }else{
   await page.mouse.move(x,y);await page.mouse.down();
   for(let i=1;i<=5;i++){await page.mouse.move(x+i*14,y+i*5);await page.waitForTimeout(65)}
   await page.mouse.up();
  }
  await page.waitForTimeout(450);
  const frames=await page.evaluate(()=>{window.samplePan=false;return window.panFrames});
  const changed=frames.slice(1).filter((p,i)=>Math.hypot(p[0]-frames[i][0],p[2]-frames[i][2])>1e-6);
  assert.ok(changed.length>8,`${name}: camera moves between sparse pointer events (${changed.length} frames)`);
  const final=await report();
  assert.notDeepEqual(final.camera,initial.camera);
  assert.equal(final.walking,false,'drag never queues walking');
  assert.equal(final.panel,'','drag over world never opens a shop');
  assert.deepEqual(final.player,initial.player,'drag leaves farmer in place');
  await screenshot('pan');
  await command('climate'); await command('scroll_bottom');
  let state=await report();
  for(const text of ['Water practice','Show weather timings']){
   const b=state.buttons.find(b=>b.text===text);assert.ok(b,text);
   assert.ok(b.rect[2]>state.modal[2]*.65 && b.rect[3]<125,`${name} ${text} compact width/height`);
  }
  await screenshot('weather-bottom');
  await command('close');
  for(const quality of ['smooth','balanced','crisp']){
   await command('quality:'+quality);await command('close');await screenshot('valley-'+quality);
  }
  console.log(name+': smooth drag, weather layout, terrain and 3 graphics modes passed');
  await context.close();
 }
 await browser.close();
 assert.deepEqual(errors,[],'browser errors');
 console.log('UPDATE BROWSER: passed without console errors');
})().catch(e=>{console.error(e);process.exit(1)});
