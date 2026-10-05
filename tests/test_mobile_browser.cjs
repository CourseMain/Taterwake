// Run against the disposable --fixture mobile export, never a saved player farm.
// Requires Playwright: NODE_PATH=/path/to/node_modules node tests/test_mobile_browser.cjs
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
require('node:fs').mkdirSync('artifacts/mobile-qa',{recursive:true});
(async()=>{
const browser=await chromium.launch({headless:true});
let errors=[];
for(const [name,width,height,touch] of [['phone',390,844,true],['phone-landscape',844,390,true],['ipad',768,1024,true],['ipad-landscape',1024,768,true],['laptop',1366,768,false]]){
 const context=await browser.newContext({viewport:{width,height},hasTouch:touch,deviceScaleFactor:name === 'phone' ? 3 : name.startsWith('ipad') ? 2 : 1});
 const page=await context.newPage();
 page.on('pageerror',e=>errors.push(name+': '+e.message));
 page.on('console',m=>{if(m.type()==='error'&& !m.text().includes('favicon'))errors.push(name+': '+m.text())});
 await page.goto(process.env.TATER_QA_URL || 'http://127.0.0.1:8766/index.html');
 await page.waitForFunction(()=>!!window.mobileQA,null,{timeout:60000});
 const command=async a=>{await page.evaluate(a=>window.mobileQA(a),a);await page.waitForTimeout(300);return page.evaluate(()=>{window.mobileQA('status');return window.mobileReport})};
 const state=await command('status');assert.equal(state.touch,touch);
 const fullRect=await page.locator('#fullscreen-button').boundingBox();
 assert.ok(fullRect.x>=width-60 && fullRect.y>=56 && fullRect.width===44, 'compact fullscreen stays clear of the top band and movement stick');
 assert.equal(await page.locator('#fullscreen-button').getAttribute('aria-label'),'Enter fullscreen');
 assert.ok(await page.locator('#fullscreen-button .fullscreen-enter').isVisible(), 'expand arrows before fullscreen');
 assert.equal(await page.locator('#fullscreen-button').evaluate(e=>getComputedStyle(e).backgroundColor),'rgba(0, 0, 0, 0)', 'fullscreen chrome is transparent');
 const shot=async suffix=>page.screenshot({path:`artifacts/mobile-qa/${name}-${suffix}.png`});
 const tapButton=async text=>{
  const s=await command('status'); const b=s.buttons.find(b=>b.text===text);assert.ok(b,`${name} button ${text}`);
  const [x,y,w,h]=b.rect;const p={x:(x+w/2)*width/s.logical[0],y:(y+h/2)*height/s.logical[1]};
  if(touch)await page.touchscreen.tap(p.x,p.y);else await page.mouse.click(p.x,p.y);
  await page.waitForTimeout(300);
 };
 await shot('farm');
 await command('near_market');
 await shot('npc-prompt');
 await tapButton('E');
 assert.equal((await command('status')).conversation.npc,'mara','NPC badge starts Mara conversation');
 await tapButton('Buy seeds');
 assert.equal((await command('status')).panel,'market','Mara opens seed counter');
 await tapButton('×');
 await page.locator('#fullscreen-button').click();
 assert.ok(await page.evaluate(()=>!!document.fullscreenElement),`${name} fullscreen entered`);
 await page.locator('#fullscreen-button .fullscreen-exit').waitFor({state:'visible'});
 assert.ok(await page.locator('#fullscreen-button .fullscreen-exit').isVisible(), 'exit cross in fullscreen');
 await page.locator('#fullscreen-button').click();
 assert.ok(await page.evaluate(()=>!document.fullscreenElement),`${name} fullscreen exited`);
 await page.locator('#fullscreen-button .fullscreen-enter').waitFor({state:'visible'});
 assert.ok(await page.locator('#fullscreen-button .fullscreen-enter').isVisible(), 'expand arrows return after fullscreen');
 if(touch){
  const cdp=await context.newCDPSession(page);const s=await command('status');const scale=width/s.logical[0];
  const points=(a,b)=>[{id:1,x:a,y:height*.47},{id:2,x:b,y:height*.47}];
  await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:points(width*.4,width*.6)});
  await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:points(width*.3,width*.7)});
  await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
  const after=await command('status');assert.ok(after.zoom<s.zoom,`${name} actual pinch zoom`);assert.equal(after.walking,false,'pinch no move');
  const stickX=105*scale,stickY=(s.logical[1]-107)*scale;
  const before=after.player;
  await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:3,x:stickX,y:stickY}]});
  await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:3,x:stickX+55*scale,y:stickY}]});
  await page.waitForTimeout(400);
  await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
  const moved=await command('status');assert.ok(Math.hypot(moved.player[0]-before[0],moved.player[1]-before[1])>.1,'actual touch movement');
  await tapButton('Hoe  /  Tools'); await shot('tools'); await tapButton('Water');
  assert.equal((await command('status')).tool,'water');
  await tapButton('Menu'); assert.equal((await command('status')).panel,'pause');
  await tapButton('×'); assert.equal((await command('status')).panel,'');
 }
 for(const action of ['menu','market','climate','close','tank','close','tutorial']){
  await command(action);await shot(action.replace(':','-'));
 }
 if(touch){
  await command('guide_shop');
  assert.equal((await command('status')).guide_visible,false,'shop owns the only visible card');
  await page.setViewportSize({width:height,height:width});await page.waitForTimeout(800);
  const rotated=await command('status');
  assert.ok(Math.abs(rotated.logical[0]/rotated.logical[1]-height/width)<.01,`${name} rotation fills screen`);
  await shot('rotated');
 }
 console.log('PASS browser',name,'fullscreen, layout',touch?'pinch, movement, tool selection, menu touch':'keyboard/mouse layout');
 await context.close();
}
console.log('BROWSER ERRORS',JSON.stringify(errors));
await browser.close();if(errors.length)process.exitCode=1;
})().catch(e=>{console.error(e);process.exit(1)});
