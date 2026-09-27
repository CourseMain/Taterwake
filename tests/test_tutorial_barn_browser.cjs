// Run against the isolated mobile QA export, never a saved player farm.
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
(async () => {
 const browser = await chromium.launch({headless:true});
 const errors = [];
 fs.mkdirSync('artifacts/tutorial-barn', {recursive:true});
 for (const [name,width,height,touch] of [['desktop',1280,800,false],['phone',390,844,true]]) {
  const context = await browser.newContext({viewport:{width,height},hasTouch:touch});
  const page = await context.newPage();
  page.on('pageerror', e => errors.push(e.message));
  page.on('console', m => {if (m.type() === 'error') errors.push(m.text());});
  await page.goto(process.env.TATER_QA_URL || 'http://127.0.0.1:8766/index.html');
  await page.waitForFunction(() => !!window.mobileQA, null, {timeout:60000});
  const report = () => page.evaluate(() => {window.mobileQA('status'); return window.mobileReport;});
  await page.evaluate(() => window.mobileQA('tutorial_sale'));
  await page.waitForTimeout(800);
  const before = await report();
  assert.equal(before.tutorial.tab, 'crops', 'remembered Gear redirects to crops');
  assert.equal(before.tutorial.active, true);
  assert.equal(before.buttons.find(b => b.action === 'inventory_tab:crops').disabled, false);
  assert.equal(before.buttons.find(b => b.action === 'inventory_tab:gear').disabled, true);
  // The sale button is inside the scrolling crop shelf, below the barn ledger.
  const canvas = await page.locator('#canvas').boundingBox();
  const clickAction = async action => {
   let s = await report();
   let b = s.buttons.find(b => b.action === action);
   assert.ok(b && !b.disabled, 'enabled ' + action);
   const scaleX = canvas.width / s.logical[0], scaleY = canvas.height / s.logical[1];
   for (let attempt = 0; attempt < 10 && b.rect[1] + b.rect[3] > s.modal[1] + s.modal[3] - 25; attempt++) {
    await page.mouse.move(canvas.x + (s.modal[0]+s.modal[2]*.7)*scaleX, canvas.y + (s.modal[1]+s.modal[3]*.7)*scaleY);
    await page.mouse.wheel(0, 180);
    await page.waitForTimeout(150);
    s = await report(); b = s.buttons.find(b => b.action === action);
   }
   const x = canvas.x + (b.rect[0]+b.rect[2]/2)*scaleX;
   const y = canvas.y + (b.rect[1]+b.rect[3]/2)*scaleY;
   assert.ok(y < canvas.y+canvas.height, 'sale is onscreen');
   await page.screenshot({path:`artifacts/tutorial-barn/${name}-sale.png`});
   if (touch) await page.touchscreen.tap(x,y); else await page.mouse.click(x,y);
   await page.waitForTimeout(500);
  };
  await clickAction('inventory_tab:crops');
  await clickAction('sell:russet:-1');
  const after = await report();
  assert.equal(after.tutorial.russets, 0, 'actual click/tap sells entire harvest');
  assert.ok(after.tutorial.coins > before.tutorial.coins, 'sale credits coins');
  assert.equal(after.tutorial.completed, true);
  assert.equal(after.tutorial.active, false);
  await page.screenshot({path:`artifacts/tutorial-barn/${name}-complete.png`});
  console.log(name + ': first sale from remembered Gear completed using ' + (touch ? 'touch' : 'mouse'));
  await context.close();
 }
 await browser.close();
 assert.deepEqual(errors, []);
})().catch(e => {console.error(e); process.exit(1);});
