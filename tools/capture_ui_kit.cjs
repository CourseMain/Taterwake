const { chromium } = require('playwright'),
  fs = require('fs'),
  assert = require('assert/strict');
// Capture the supplied kit beside an isolated surfaces fixture.
const dir = process.env.TATER_KIT_OUTPUT || 'docs/style-board/v2.0.4';
fs.mkdirSync(dir, { recursive: true });
const cases = [
  ['farmer', 'Your farmer'],
  ['menu', 'Menu is a board'],
  ['accounts', 'A keeper page'],
  ['market', 'A keeper page'],
  ['kit_winter', 'The Winter card'],
  ['grades', 'Grade stamps'],
  ['practice', 'The practice tile'],
  ['sale_reveal', 'The sale reveal'],
];
(async () => {
  const browser = await chromium.launch({
    executablePath: process.env.CHROME_EXECUTABLE || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    headless: true,
    args: ['--use-angle=metal'],
  });
  try {
    const game = await browser.newPage({
      viewport: { width: 390, height: 844 },
      hasTouch: true,
      isMobile: true,
    });
    let errors = [];
    game.on('console', (m) => {
      if (m.type() === 'error') errors.push(m.text());
    });
    game.on('pageerror', (e) => errors.push(e.message));
    await game.goto(process.env.TATER_KIT_QA_URL || 'http://127.0.0.1:8965/');
    await game.waitForFunction(() => window.surfaceReport?.ready, { timeout: 120000 });
    const refs = await browser.newPage({ viewport: { width: 390, height: 844 } });
    const results = [];
    for (const [id, heading] of cases) {
      let request = await game.evaluate(() => surfaceReport.request);
      await game.evaluate((id) => surfaceQA(id), id);
      await game.waitForFunction(
        (n) => surfaceReport?.ready && surfaceReport.request > n,
        request,
        { timeout: 90000 },
      );
      await game.evaluate(() => surfaceQA('status'));
      const report = await game.evaluate(() => surfaceReport);
      assert.equal(report.content_fits_width, true, id + ' fits width');
      await game.screenshot({ path: dir + '/' + id + '-built.png' });
      await refs.goto(
        process.env.TATER_KIT_REFERENCE_URL || 'http://127.0.0.1:8955/docs/style-board/ui-kit.html',
      );
      await refs.evaluate((heading) => {
        let h = [...document.querySelectorAll('h2')].find((e) => e.textContent.includes(heading)),
          e = h.nextElementSibling;
        while (e && !e.classList.contains('felt')) e = e.nextElementSibling;
        if (!e) throw Error(heading);
        document.body.replaceChildren(e.cloneNode(true));
        const style = document.createElement('style');
        style.textContent = `
     @font-face{font-family:Slackey;src:url('/assets/fonts/Slackey.ttf')}@font-face{font-family:'Atkinson Hyperlegible';src:url('/assets/fonts/AtkinsonHyperlegible.ttf')}
     body{background:#17382d;width:390px;height:844px;overflow:hidden}.felt,.felt.phone{width:390px;max-width:390px;height:844px;margin:0;border-radius:0;padding:12px;justify-content:center;align-content:center;align-items:center}.tile .rar{display:none}.card .line,.opts .o{font-size:14px}.grid6 .t{font-size:14px}.board h3{font-size:22px}.khead .who,.card .name{font-size:22px}.stamp{font-size:16px}.felt>div>div[style*=".85rem"]{font-size:14px!important}
    `;
        document.head.appendChild(style);
      }, heading);
      await refs.evaluate(() => document.fonts.ready);
      await refs.waitForTimeout(3000);
      await refs.screenshot({ path: dir + '/' + id + '-reference.png' });
      // Computer captures come from tests/test_kit_browser.cjs.
      const actual = fs.readFileSync(dir + '/' + id + '-built.png').toString('base64'),
        ref = fs.readFileSync(dir + '/' + id + '-reference.png').toString('base64');
      const pair = await browser.newPage({ viewport: { width: 800, height: 884 } });
      await pair.setContent(
        `<style>*{box-sizing:border-box}body{margin:0;background:#17382d;color:#fffbed;font:16px system-ui;display:grid;grid-template-columns:390px 390px;gap:20px}p{height:40px;margin:0;padding:9px 12px}img{display:block;width:390px;height:844px}</style><section><p>${id === 'market' ? 'Kit keeper primitives (no Mara mockup supplied)' : 'Kit reference'}</p><img src="data:image/png;base64,${ref}"></section><section><p>Built game · 390 × 844</p><img src="data:image/png;base64,${actual}"></section>`,
      );
      await pair.screenshot({ path: dir + '/' + id + '-comparison.png' });
      await pair.close();
      const desktop = fs.readFileSync(dir + '/' + id + '-desktop.png').toString('base64');
      const desktopPair = await browser.newPage({ viewport: { width: 1850, height: 940 } });
      await desktopPair.setContent(
        `<style>*{box-sizing:border-box}body{margin:0;background:#17382d;color:#fffbed;font:16px system-ui;display:grid;grid-template-columns:390px 1440px;gap:20px}p{height:40px;margin:0;padding:9px 12px}img{display:block;max-width:100%}</style><section><p>${id === 'market' ? 'Kit keeper primitives' : 'Original phone kit'}</p><img src="data:image/png;base64,${ref}"></section><section><p>Owner’s computer layout · 1440 × 900</p><img src="data:image/png;base64,${desktop}"></section>`,
      );
      await desktopPair.screenshot({ path: dir + '/' + id + '-desktop-comparison.png' });
      await desktopPair.close();
      results.push({ id, reference: heading, report });
      console.log('Captured', id);
    }
    assert.deepEqual(errors, []);
    fs.writeFileSync(
      'artifacts/v204-kit-browser-report.json',
      JSON.stringify({ results, errors }, null, 2) + '\n',
    );
  } finally {
    await browser.close();
  }
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
