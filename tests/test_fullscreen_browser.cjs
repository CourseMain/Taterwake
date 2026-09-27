// Exercise fullscreen from the source shell without an export or player save.
const {chromium} = require('playwright');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

let shell = fs.readFileSync(path.join(__dirname, '../web/shell.html'), 'utf8');
shell = shell.replace('<script src="$GODOT_URL"></script>', `<script>
class Engine {
 static getMissingFeatures() { return []; }
 startGame() { document.getElementById('canvas').tabIndex = 0; return Promise.resolve(); }
}
</script>`)
 .replaceAll('$GODOT_CONFIG', '{}')
 .replaceAll('$GODOT_THREADS_ENABLED', 'false')
 .replaceAll('$GODOT_SPLASH_COLOR', '#193c33')
 .replaceAll('$GODOT_PROJECT_NAME', 'Taterland')
 .replaceAll('$GODOT_HEAD_INCLUDE', '')
 .replaceAll('$GODOT_SPLASH_CLASSES', '')
 .replaceAll('$GODOT_SPLASH', '');

(async () => {
 const browser = await chromium.launch({headless: true});
 try {
  for (const [width, height, hasTouch] of [[1280, 800, false], [390, 844, true], [844, 390, true]]) {
   const context = await browser.newContext({viewport: {width, height}, hasTouch});
   const page = await context.newPage();
   const errors = [];
   page.on('pageerror', error => errors.push(error.message));
   await page.setContent(shell);
   const button = page.locator('#fullscreen-button');
   const enter = button.locator('.fullscreen-enter');
   const exit = button.locator('.fullscreen-exit');
   const bounds = await button.boundingBox();
   assert.equal(bounds.width, 44, '44px invisible horizontal hit target');
   assert.equal(bounds.height, 44, '44px invisible vertical hit target');
   assert.equal(await button.evaluate(el => getComputedStyle(el).backgroundColor), 'rgba(0, 0, 0, 0)');
   assert.equal(await button.evaluate(el => getComputedStyle(el).borderWidth), '0px');
   assert.ok(await enter.isVisible(), 'enter state shows expansion arrows');
   assert.equal(await enter.evaluate(el => el.getBoundingClientRect().width), 22, 'icon is smaller than its hit target');
   await button.click();
   await page.waitForFunction(() => !!document.fullscreenElement);
   await exit.waitFor({state: 'visible'});
   assert.ok(await exit.isVisible(), 'trusted click enters fullscreen and shows exit cross');
   assert.equal(await button.getAttribute('aria-label'), 'Exit fullscreen');
   assert.equal(await page.evaluate(() => document.activeElement.id), 'canvas', 'input focus returns to the farm');
   await button.click();
   await page.waitForFunction(() => !document.fullscreenElement);
   await enter.waitFor({state: 'visible'});
   assert.ok(await enter.isVisible(), 'exit restores expansion arrows');
   await page.keyboard.press('F11');
   await page.waitForFunction(() => !!document.fullscreenElement);
   await exit.waitFor({state: 'visible'});
   assert.ok(await exit.isVisible(), 'F11 updates the icon');
   await page.evaluate(() => document.exitFullscreen());
   await page.waitForFunction(() => document.getElementById('fullscreen-button').getAttribute('aria-pressed') === 'false');
   assert.ok(await enter.isVisible(), 'external fullscreen exit also restores the icon');
   assert.deepEqual(errors, []);
   console.log(`FULLSCREEN SOURCE: ${width}×${height} passed`);
   await context.close();
  }
 } finally {
  await browser.close();
 }
})().catch(error => { console.error(error); process.exitCode = 1; });
