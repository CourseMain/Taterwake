// Capture the disposable surfaces fixture, never a player's save.
// NODE_PATH=<directory containing playwright> node tests/capture_surfaces_browser.cjs \
//   http://127.0.0.1:8911/index.html docs/style-board/taterland-after --all
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const [url, output] = process.argv.slice(2);
if (!url || !output) throw new Error('Supply fixture URL and output directory.');
const extra = process.argv.includes('--all');
const width = process.argv.includes('--desktop') ? 1280 : 390;
const height = width === 390 ? 844 : 800;
const dpr = Number(process.argv.find(a => a.startsWith('--dpr='))?.split('=')[1] || 1);
(async () => {
  const browser = await chromium.launch({
    executablePath: process.env.CHROME_BIN || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    headless: true, args: ['--use-angle=metal'],
  });
  const context = await browser.newContext({viewport: {width, height}, deviceScaleFactor: dpr, isMobile: width === 390, hasTouch: width === 390});
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  const reports = [];
  fs.mkdirSync(output, {recursive: true});
  try {
    await page.goto(url);
    await page.waitForFunction(() => typeof window.surfaceQA === 'function' && window.surfaceReport?.ready, null, {timeout: 90000});
    const pages = width === 1280 ? [['menu', 'menu']] : [['title', 'title'], ['accounts', 'accounts'], ['market', 'crop-card'], ['climate', 'forecast']];
    if (process.argv.includes('--advice')) pages.splice(0, pages.length, ...['harvest', 'barn', 'sell_potatoes', 'spring_target', 'year1_accounts', 'winter_jobs', 'winter_seed_choices'].map(p => [p,p]));
    if (extra) pages.push(...['menu', 'barn', 'tools', 'quests', 'loss_notices', 'contracts', 'sell_potatoes', 'front_page', 'npc:nell', 'run_summary', 'foreclosure', 'graphics', 'debug', 'help', 'activities', 'dex'].map(p => [p, p.replace(':', '-')]));
    for (const [command, name] of pages) {
      const previous = await page.evaluate(() => window.surfaceReport.request);
      await page.evaluate(action => window.surfaceQA(action), command);
      await page.waitForFunction(({previous, command}) => window.surfaceReport?.ready && window.surfaceReport.request > previous && window.surfaceReport.page === command.split(':')[0], {previous, command}, {timeout: 60000});
      const report = await page.evaluate(() => window.surfaceReport);
      assert.deepEqual(report.backing_size, [width * Math.min(dpr, 2), height * Math.min(dpr, 2)], `${name}: backing resolution`);
      if (!['title', 'npc:nell', 'front_page', 'foreclosure', 'harvest', 'spring_target', 'winter_jobs'].includes(command)) assert.ok(report.content_fits_width, `${name}: content fits width`);
      assert.deepEqual(errors, [], `${name}: browser errors`);
      if (process.argv.includes('--advice') && ['harvest', 'barn', 'sell_potatoes'].includes(command)) {
        const stamps = [...report.labels, ...report.buttons].filter(n => n.grade);
        assert.ok(stamps.length > 0, `${name}: visible grade stamps`);
        for (const stamp of stamps) assert.ok(stamp.font_size * width / report.logical_size[0] >= 14, `${name}: ${stamp.text} at least 14 CSS px at DPR ${dpr}`);
      }
      await page.screenshot({path: path.join(output, `${name}.png`)});
      reports.push(report);
      console.log(`CAPTURE ${width}x${height} ${name}`);
      if (extra && command === 'title') {
        await page.waitForTimeout(8500);
        await page.screenshot({path: path.join(output, 'title-pullback.png')});
      }
      if (extra && ['accounts', 'run_summary', 'foreclosure'].includes(command)) {
        await page.evaluate(() => window.surfaceQA('scroll:end'));
        await page.waitForFunction(() => window.surfaceReport.ready);
        await page.screenshot({path: path.join(output, `${name}-end.png`)});
      }
    }
    fs.writeFileSync(path.join(output, 'capture-report.json'), JSON.stringify({url, viewport: {width, height}, dpr, errors, reports}, null, 2) + '\n');
  } finally { await context.close(); await browser.close(); }
})().catch(error => {console.error(error); process.exitCode = 1;});
