const { chromium } = require('playwright');
const fs = require('node:fs');
const assert = require('node:assert/strict');
(async () => {
 const browser = await chromium.launch({headless:true, executablePath:process.env.CHROME_EXECUTABLE || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',args:['--use-angle=metal']});
 const samples = [], errors = [];
 try {
  for (let i=0;i<3;i++) {
   const context = await browser.newContext({viewport:{width:390,height:844},hasTouch:true,isMobile:true,serviceWorkers:'block'});
   const page = await context.newPage();
   page.on('pageerror',e=>errors.push(e.message));
   page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
   const client = await context.newCDPSession(page);
   await client.send('Network.enable');
   await client.send('Network.setCacheDisabled',{cacheDisabled:true});
   await client.send('Network.emulateNetworkConditions',{offline:false,latency:40,downloadThroughput:1250000,uploadThroughput:1250000});
   await page.goto(process.argv[2],{waitUntil:'domcontentloaded',timeout:120000});
   await page.waitForFunction(()=>!document.querySelector('#status'),null,{timeout:120000});
   const data=await page.evaluate(()=>({ready_ms:performance.now(),resources:performance.getEntriesByType('resource').filter(r=>/index\.(pck|wasm)$/.test(r.name)).map(r=>({name:r.name.split('/').pop(),bytes:r.encodedBodySize,transfer_ms:r.duration}))}));
   samples.push(data);console.log(JSON.stringify(data));
   await context.close();
  }
  assert.deepEqual(errors,[]);
 } finally {
  fs.writeFileSync(process.argv[3],JSON.stringify({viewport:[390,844],network:'10 Mbps, 40 ms latency, uncached, service workers blocked',samples,median_ready_ms:samples.map(s=>s.ready_ms).sort((a,b)=>a-b)[1],errors},null,2)+'\n');
  await browser.close();
 }
})().catch(e=>{console.error(e);process.exit(1)});
