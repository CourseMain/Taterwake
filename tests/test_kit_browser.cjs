const { chromium } = require('playwright'),
  fs = require('fs'),
  assert = require('assert/strict');
// Run against an isolated surfaces fixture, never a saved player farm.
const out = process.env.TATER_KIT_OUTPUT || 'docs/style-board/v2.0.4';
fs.mkdirSync(out, { recursive: true });
(async () => {
  const browser = await chromium.launch({
    executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    headless: true,
    args: ['--use-angle=metal'],
  });
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 900 } }),
      errors = [];
    page.on('pageerror', (e) => errors.push(e.message));
    page.on('console', (m) => {
      if (m.type() === 'error') errors.push(m.text());
    });
    await page.goto(process.env.TATER_KIT_QA_URL || 'http://127.0.0.1:8962/');
    await page.waitForFunction(() => window.surfaceReport?.ready, { timeout: 120000 });
    const status = async () => {
      await page.evaluate(() => surfaceQA('status'));
      return page.evaluate(() => surfaceReport);
    };
    const open = async (id) => {
      const n = (await status()).request;
      await page.evaluate((id) => surfaceQA(id), id);
      await page.waitForFunction((n) => surfaceReport.ready && surfaceReport.request > n, n, {
        timeout: 90000,
      });
      await page.waitForTimeout(700);
      return status();
    };
    const click = async (action) => {
      let s = await status(),
        b = s.buttons.find((b) => b.action === action && !b.disabled);
      assert.ok(b, 'active ' + action);
      const r = b.rect,
        c = await page.locator('#canvas').boundingBox();
      await page.mouse.click(
        c.x + ((r[0] + r[2] / 2) * c.width) / s.logical_size[0],
        c.y + ((r[1] + r[3] / 2) * c.height) / s.logical_size[1],
      );
      await page.waitForTimeout(700);
      return status();
    };
    const results = [];
    for (const id of [
      'farmer',
      'menu',
      'accounts',
      'market',
      'market_sell',
      'barn',
      'tools',
      'kit_winter',
      'grades',
      'practice',
      'sale_reveal',
    ]) {
      const s = await open(id);
      assert.equal(s.content_fits_width, true, id + ' fits horizontally');
      if (!['kit_winter'].includes(id)) {
        assert.ok(
          s.modal[0] >= 0 &&
            s.modal[1] >= 0 &&
            s.modal[0] + s.modal[2] <= s.logical_size[0] + 1 &&
            s.modal[1] + s.modal[3] <= s.logical_size[1] + 1,
          id + ' fits normal window',
        );
      }
      await page.screenshot({ path: out + '/' + id + '-desktop.png' });
      results.push({ id, ...s });
      console.log('Desktop', id);
    }
    for (const size of [
      [960, 600],
      [1440, 900],
      [2888, 1804],
    ]) {
      await page.setViewportSize({ width: size[0], height: size[1] });
      await open('market');
      let s = await status();
      for (const [x, y] of [
        [0.2, 0.15],
        [0.9, 0.2],
        [0.3, 0.5],
        [0.7, 0.7],
        [0.5, 0.3],
      ]) {
        await page.mouse.move(size[0] * x, size[1] * y);
        await page.waitForTimeout(220);
        const after = await status();
        assert.deepEqual(after.modal, s.modal, 'whole shop stays still under mouse at ' + size);
      }
      assert.equal(
        s.buttons.filter((b) => b.action.startsWith('buy:') && b.action.endsWith(':1')).length,
        5,
        'all five seed cards visible in a normal window',
      );
      assert.ok(
        s.buttons.some((b) => b.action === 'close'),
        'close visible',
      );
      await click('market_mode:sell');
      s = await status();
      assert.equal(s.panel_kind, 'market');
      assert.equal(
        s.buttons.filter((b) => b.action === 'market_sell').length,
        1,
        'one Sell action',
      );
      assert.equal(
        s.buttons.filter((b) => b.action.startsWith('sale_stock:')).length,
        0,
        'one current stock',
      );
      await click('market_mode:buy');
      s = await status();
      assert.ok(
        s.buttons.some((b) => b.action === 'buy:golden:1'),
        'Buy returns to seeds',
      );
    }
    await page.setViewportSize({ width: 1440, height: 900 });
    await open('menu');
    await click('save_page');
    let s = await click('request_reset');
    assert.ok(
      s.labels.some((l) => l.text === 'Plant a new farm?'),
      'New Farm confirmation visible',
    );
    await page.screenshot({ path: out + '/new-farm-desktop.png' });
    s = await click('cancel_reset');
    assert.ok(
      s.buttons.some((b) => b.action === 'save_page'),
      'cancel returns to Menu',
    );
    await click('save_page');
    await click('request_reset');
    await click('reset');
    s = await status();
    assert.equal(s.year, 1);
    assert.equal(s.season, 'Spring');
    assert.deepEqual(errors, []);
    console.log('New Farm browser buttons passed; no browser errors');
    fs.writeFileSync(
      'artifacts/v204-desktop-review.json',
      JSON.stringify({ results, errors }, null, 2) + '\n',
    );
  } finally {
    await browser.close();
  }
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
