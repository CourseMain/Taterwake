// Run against the isolated --fixture mobile export; never a saved player farm.
const { chromium } = require('playwright');
const { PNG } = require('pngjs');
require('node:fs').mkdirSync('artifacts/mobile-qa', { recursive: true });
const assert = require('node:assert/strict');
const url = process.env.NPC_QA_URL || 'http://127.0.0.1:8777/index.html';
(async () => {
  const browser = await chromium.launch({ headless: true });
  try {
    for (const [name, width, height, touch] of [
      ['laptop', 1280, 800, false], ['phone', 390, 844, true],
      ['phone-landscape', 844, 390, true], ['ipad', 768, 1024, true], ['ipad-landscape', 1024, 768, true],
    ].filter(row => !process.env.NPC_QA_SIZES || process.env.NPC_QA_SIZES.split(',').includes(row[0]))) {
      const context = await browser.newContext({ viewport: { width, height }, hasTouch: touch });
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror', e => errors.push(e.message));
      page.on('console', m => { if (m.type() === 'error' && !m.text().includes('favicon')) errors.push(m.text()); });
      await page.goto(url);
      await page.waitForFunction(() => !!window.mobileQA, null, { timeout: 60000 });
      const command = async action => {
        await page.evaluate(action => window.mobileQA(action), action);
        await page.waitForTimeout(250);
        return page.evaluate(() => { window.mobileQA('status'); return window.mobileReport; });
      };
      const click = async text => {
        const report = await command('status');
        const b = report.buttons.find(b => b.text === text);
        assert.ok(b, `${name}: missing ${text}`);
        const [x, y, w, h] = b.rect;
        assert.ok(x >= 0 && y >= 0 && x + w <= report.logical[0] + 1 && y + h <= report.logical[1] + 1, `${name}: offscreen ${text}`);
        const actual = page.viewportSize();
        const px = (x + w / 2) * actual.width / report.logical[0];
        const py = (y + h / 2) * actual.height / report.logical[1];
        if (touch) await page.touchscreen.tap(px, py); else await page.mouse.click(px, py);
        await page.waitForTimeout(350);
      };
      const shot = async label => page.screenshot({ path: `artifacts/mobile-qa/npc-${name}-${label}.png` });
      await command('near_market');
      await page.waitForTimeout(500);
      await shot('stall');
      await click('E');
      let report = await command('status');
      assert.equal(report.conversation.visible, true);
      assert.equal(report.conversation.npc, 'mara');
      assert.equal(report.panel, '');
      const clock = report.conversation.clock;
      await page.waitForTimeout(4300);
      assert.equal((await command('status')).conversation.clock, clock, 'time must pause');
      await shot('mara');
      if (name === 'phone') {
        await page.setViewportSize({ width: 844, height: 390 });
        await page.waitForTimeout(900);
        const pixels = PNG.sync.read(await page.screenshot({ path: 'artifacts/mobile-qa/npc-rotation-verified.png' }));
        // Logical rectangles can be correct while Godot keeps an old letterbox.
        // Check the rendered canvas edges as well as clicking a choice below.
        for (const x of [10, pixels.width - 10]) {
          const i = (Math.floor(pixels.height / 2) * pixels.width + x) * 4;
          assert.ok(pixels.data[i] + pixels.data[i + 1] + pixels.data[i + 2] > 15, 'rotation must not leave black side bars');
        }
        assert.equal((await command('status')).conversation.clock, clock);
      }
      await click('Lost something again?');
      assert.equal((await command('status')).conversation.page, 'story');
      await click("I'll keep an eye out.");
      assert.match((await command('status')).conversation.text, /behind my ear/);
      await click('Any planting advice?');
      assert.equal((await command('status')).conversation.page, 'advice');
      await click('Browse seeds');
      const returned = await command('status');
      assert.equal(returned.panel, 'market');
      assert.ok(!returned.buttons.some(b => b.text.startsWith('Talk to')), 'shop follows conversation without another Talk button');
      await shot('shop');
      assert.ok(returned.modal[1] + returned.modal[3] <= returned.logical[1] + 1, 'shop still fits after rotating in dialogue: ' + JSON.stringify({modal:returned.modal,logical:returned.logical}));
      if (name === 'phone') {
        await page.setViewportSize({ width: 390, height: 844 });
        await page.waitForTimeout(800);
      }
      await command('user:market');
      assert.match((await command('status')).conversation.text, /Found the pencil/);
      await click('Leave  ×');
      assert.equal((await command('status')).conversation.visible, false);
      if (name === 'laptop') {
        for (const [id, action] of [['bram','tools'],['nell','barn'],['pip','duck_patrol'],['ada','builds'],['rook','roll'],['hollis','island'],['tess','quests'],['edwin','taxes']]) {
          await command('user:' + action);
          assert.equal((await command('status')).conversation.npc, id);
          await page.keyboard.press('Space');
          await shot(id);
          await page.keyboard.press('Escape');
          assert.equal((await command('status')).conversation.visible, false);
        }
      }
      if (!touch) {
        await command('user:market');
        await page.locator('#fullscreen-button').click();
        await page.waitForFunction(() => !!document.fullscreenElement);
        await page.evaluate(() => document.exitFullscreen());
        await page.waitForTimeout(300);
        await page.keyboard.press('Escape');
        assert.equal((await command('status')).conversation.visible, false, 'keyboard focus returns after fullscreen');
      }
      await command('island2');
      await command('user:climate');
      await page.waitForTimeout(3500);
      await shot('iris');
      await click('See weather & protection');
      assert.equal((await command('status')).panel, 'climate');
      await command('freeze');
      await command('user:activities');
      await click("How's the weather looking?");
      await page.waitForTimeout(4500);
      await shot('oren');
      assert.match((await command('status')).conversation.text, /heat it again for free/);
      await click('Open the furnace');
      assert.equal((await command('status')).panel, 'activities');
      assert.deepEqual(errors, [], `${name}: browser errors`);
      console.log(`PASS ${name}: portraits, touch/mouse choices, memories, paused clocks, weather branches, service return`);
      await context.close();
    }
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exit(1); });
