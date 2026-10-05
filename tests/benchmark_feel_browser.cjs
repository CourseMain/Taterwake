// Export --fixture feel into artifacts, then serve that disposable build.
// NODE_PATH=artifacts/release-i-tooling/node_modules node tests/benchmark_feel_browser.cjs
// Optional: --year --input=touch, or --cdp=http://localhost:9222 --physical.
// A desktop browser with phone emulation is never reported as a real phone.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

function argument(name, fallback) {
  const direct = process.argv.find(value => value.startsWith(`--${name}=`));
  if (direct) return direct.slice(name.length + 3);
  const index = process.argv.indexOf(`--${name}`);
  return index >= 0 && process.argv[index + 1] && !process.argv[index + 1].startsWith('--')
    ? process.argv[index + 1] : fallback;
}
const flag = name => process.argv.includes(`--${name}`);
const url = argument('url', process.env.TATER_FEEL_URL || 'http://127.0.0.1:8790/index.html');
const label = argument('label', 'current');
assert.match(label, /^[a-zA-Z0-9-]+$/);
const duration = Number(argument('duration', '12'));
assert.ok(Number.isFinite(duration) && duration >= 2 && duration <= 20, 'Rain sample stays inside the real 30-second weather phase.');
const cdpURL = argument('cdp', process.env.TATER_CDP_URL || '');
const physical = flag('physical');
assert.ok(!physical || cdpURL, '--physical requires a remote browser connection, not desktop emulation.');
const input = argument('input', 'keyboard');
assert.ok(['keyboard', 'touch'].includes(input));
const output = argument('output', `artifacts/feel-browser/${label}.json`);
const directory = path.dirname(output);
fs.mkdirSync(directory, { recursive: true });

function statistics(values) {
  const sorted = [...values].sort((a, b) => a - b);
  if (!sorted.length) return { count: 0 };
  const percentile = fraction => sorted[Math.max(0, Math.ceil(sorted.length * fraction) - 1)];
  const total = sorted.reduce((sum, value) => sum + value, 0);
  return { count: sorted.length, mean: total / sorted.length, median: percentile(.5),
    p95: percentile(.95), p99: percentile(.99), max: sorted.at(-1), fps: sorted.length * 1000 / total };
}

async function main() {
  const errors = [];
  const browser = cdpURL
    ? await chromium.connectOverCDP(cdpURL)
    : await chromium.launch({ headless: !flag('headful'),
        executablePath: argument('chrome', process.env.CHROME_EXECUTABLE || undefined) });
  const context = cdpURL ? browser.contexts()[0]
    : await browser.newContext({ viewport: { width: 390, height: 844 }, hasTouch: true,
        deviceScaleFactor: 3, isMobile: true,
        userAgent: 'Mozilla/5.0 (Linux; Android 13; PhoneEmulation) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36' });
  assert.ok(context, 'The remote browser must have an accessible context.');
  const page = await context.newPage();
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {
    const text = message.text();
    if (message.type() === 'error' && !text.includes('favicon')) errors.push(text);
  });
  const report = { label, url, recorded_at: new Date().toISOString(), arguments: process.argv.slice(2),
    browser_version: browser.version(), measurement_mode: cdpURL
      ? (physical ? 'remote physical phone declared by operator' : 'remote browser; hardware unverified')
      : 'desktop Chromium with phone viewport, touch and DPR emulation',
    physical_phone: physical, hardware_verification: physical
      ? 'Operator declaration over CDP; device model and real frame rate must be checked against the metadata.'
      : 'No physical phone measurement is claimed.', target_fps: 60, target_frame_ms: 1000 / 60,
    results: [], errors, success: false, status: 'running' };
  try {
    await page.goto(url);
    await page.waitForFunction(() => !!window.feelQA && window.feelReport?.ready, null, { timeout: 120000 });
    await page.locator('#canvas').click({ position: { x: 20, y: 200 } });
    await page.waitForTimeout(600);
    report.browser_metadata = await page.evaluate(() => {
      const canvas = document.getElementById('canvas');
      const gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
      const debug = gl && gl.getExtension('WEBGL_debug_renderer_info');
      const bounds = canvas.getBoundingClientRect();
      return { user_agent: navigator.userAgent, platform: navigator.platform,
        hardware_concurrency: navigator.hardwareConcurrency, device_memory_gb: navigator.deviceMemory ?? null,
        touch_points: navigator.maxTouchPoints, device_pixel_ratio: devicePixelRatio,
        viewport_css: [innerWidth, innerHeight], screen_css: [screen.width, screen.height],
        canvas_css: [bounds.x, bounds.y, bounds.width, bounds.height],
        canvas_backing: [canvas.width, canvas.height], visibility: document.visibilityState,
        webgl: gl ? { vendor: gl.getParameter(gl.VENDOR), renderer: gl.getParameter(gl.RENDERER),
          version: gl.getParameter(gl.VERSION), shading_language: gl.getParameter(gl.SHADING_LANGUAGE_VERSION),
          unmasked_vendor: debug ? gl.getParameter(debug.UNMASKED_VENDOR_WEBGL) : null,
          unmasked_renderer: debug ? gl.getParameter(debug.UNMASKED_RENDERER_WEBGL) : null } : null };
    });
    assert.equal(await page.evaluate(() => window.feelReport.metadata.test_mode), true);
    assert.equal(await page.evaluate(() => window.feelReport.metadata.save_path), 'user://feel-benchmark-test-only.json');
    assert.equal(await page.evaluate(() => window.feelReport.state.touch), true, 'Real game touch layout is enabled.');
    if (!cdpURL) {
      assert.deepEqual(report.browser_metadata.viewport_css, [390, 844]);
      assert.equal(report.browser_metadata.device_pixel_ratio, 3);
    }
    try {
      const session = await browser.newBrowserCDPSession();
      const info = await session.send('SystemInfo.getInfo');
      report.browser_gpu = info.gpu;
      await session.detach();
    } catch (error) { report.browser_gpu_unavailable = error.message; }

    const command = async action => page.evaluate(action => {
      window.feelQA(action);
      return window.feelReport;
    }, action);
    const state = async () => (await command('status')).state;
    const beginRAF = async id => page.evaluate(id => {
      window.feelRAF = { id, intervals: [], last: 0, done: false };
      const sample = stamp => {
        const trace = window.feelRAF;
        if (trace.id !== id || trace.done) return;
        if (trace.last) trace.intervals.push(stamp - trace.last);
        trace.last = stamp;
        if (window.feelReport.measurements.some(result => result.id === id)) trace.done = true;
        else requestAnimationFrame(sample);
      };
      requestAnimationFrame(sample);
    }, id);
    const collect = async id => {
      await page.waitForFunction(id => window.feelReport.measurements.some(result => result.id === id), id,
        { timeout: id.startsWith('full_year') ? 920000 : 60000, polling: 100 });
      const result = await page.evaluate(id => window.feelReport.measurements.find(result => result.id === id), id);
      const raf = await page.evaluate(() => { window.feelRAF.done = true; return window.feelRAF.intervals; });
      result.browser_raf_ms = statistics(raf);
      report.results.push(result);
      fs.writeFileSync(output, JSON.stringify(report, null, 2) + '\n');
      console.log(`FEEL ${label} ${id}: ${result.fps.toFixed(1)} fps, median ${result.frame_ms.median.toFixed(2)} ms, p95 ${result.frame_ms.p95.toFixed(2)} ms, p99 ${result.frame_ms.p99.toFixed(2)} ms, max ${result.frame_ms.max.toFixed(2)} ms`);
      assert.equal(result.error, '');
      return result;
    };

    if (!flag('boundary-only') && !flag('year-only')) {
    const sampledShadows = new Set();
    for (const size of (argument('shadows','2048') === '2048' ? [2048] : [4096, 2048])) {
      let id = `summer_rain_shadow_${size}`;
      console.log(`Starting ${label} ${id}, ${duration}s after 3s warmup`);
      await command(`rain:${size}:${duration}`);
      id = await page.evaluate(() => window.feelReport.sample.id);
      if (sampledShadows.has(id)) continue;
      sampledShadows.add(id);
      await page.waitForFunction(id => window.feelReport.sample.id === id && window.feelReport.sample.sampling, id,
        { timeout: 15000, polling: 100 });
      await beginRAF(id);
      await collect(id);
      await page.screenshot({ path: path.join(directory, `${label}-${id}.png`) });
    }
    if (report.results.length === 2) {
    const high = report.results[0];
    const low = report.results[1];
    report.shadow_comparison = { high: high.shadow_size, low: low.shadow_size,
      median_delta_ms: low.frame_ms.median - high.frame_ms.median,
      p95_delta_ms: low.frame_ms.p95 - high.frame_ms.p95,
      fps_delta: low.fps - high.fps,
      note: physical ? 'Measurements from the declared remote phone.'
        : 'Desktop phone emulation compares renderer cost; it cannot decide the real-phone shadow budget.' };
    }
    }

    if (!flag('year-only')) {
    for (const mode of ['ordinary', 'stress']) {
      const id = mode === 'stress' ? 'boundary_year10_3000_entries' : 'boundary_ordinary_year1';
      console.log(`Starting ${label} ${id}`);
      await command(`boundary:${mode}`);
      await beginRAF(id);
      const result = await collect(id);
      assert.equal(result.boundaries.length, 1, 'One real Autumn-to-Winter boundary ran.');
      assert.equal(result.boundaries[0].season, 3);
      assert.equal(result.saved_boundary.season, 3, 'The normal boundary save contains Winter.');
      assert.ok(result.boundaries[0].file_bytes > 0);
      if (mode === 'stress') assert.ok(result.saved_journal_entries >= 3000);
      console.log(`SAVE ${label} ${id}: ${result.boundaries[0].save_ms.toFixed(3)} ms, ${result.boundaries[0].file_bytes} bytes`);
      await page.screenshot({ path: path.join(directory, `${label}-${id}.png`) });
    }
    }

    if (flag('year') || flag('year-only')) {
      const point = async button => {
        const current = await state();
        const bounds = await page.locator('#canvas').boundingBox();
        const [x, y, width, height] = button.rect;
        return { x: bounds.x + (x + width / 2) * bounds.width / current.logical_canvas[0],
          y: bounds.y + (y + height / 2) * bounds.height / current.logical_canvas[1] };
      };
      console.log(`Starting ${label} full year at normal speed; 150s seasons.`);
      await command('year');
      await beginRAF('full_year_normal_speed');
      const started = Date.now();
      let closedPages = 0;
      while (Date.now() - started < 910000) {
        if (await page.evaluate(() => window.feelReport.measurements.some(result => result.id === 'full_year_normal_speed'))) break;
        const current = await state();
        assert.equal(current.run_over, false);
        if (current.accounts || current.cause_card || current.conversation) {
          const button = current.buttons.find(button => button.action === 'close' && !button.disabled)
            || current.buttons.find(button => /return to farm|back to farm|continue|skip|finish|goodbye/i.test(button.text) && !button.disabled);
          assert.ok(button, 'A paused page has a normal visible way to continue.');
          const location = await point(button);
          await page.touchscreen.tap(location.x, location.y);
          closedPages++;
        }
        await page.waitForTimeout(500);
      }
      const result = await collect('full_year_normal_speed');
      result.input = input;
      result.closed_pages_with_real_taps = closedPages;
      assert.equal(result.boundaries.length, 4, 'A full year reached all four ordinary boundary saves.');
      assert.deepEqual(result.boundaries.map(boundary => boundary.season), [1, 2, 3, 0]);
      assert.equal(result.saved_boundary.year, 2);
      assert.equal(result.saved_boundary.season, 0);
      assert.ok(result.observed_pace <= 1.01, 'The year advances at normal speed.');
      await page.screenshot({ path: path.join(directory, `${label}-full-year.png`) });
    }
    report.performance_limitations = ['Frame intervals include browser scheduling and rendering; process monitors are engine CPU measurements, not GPU timings.',
      'Full-year measurements include normal page transitions and the fixture polling visible controls every 500 ms.',
      'An emulated phone viewport does not establish performance on a mid-range physical phone.'];
    assert.deepEqual(errors, [], 'No script, browser or export errors.');
    report.success = true;
  } catch (error) {
    report.runner_error = error.stack;
    throw error;
  } finally {
    report.status = report.success ? 'passed' : 'failed';
    fs.writeFileSync(output, JSON.stringify(report, null, 2) + '\n');
    await page.close();
    if (!cdpURL) await browser.close();
  }
  console.log(`Report: ${output}`);
}

main().then(() => process.exit(0)).catch(error => { console.error(error); process.exit(1); });
