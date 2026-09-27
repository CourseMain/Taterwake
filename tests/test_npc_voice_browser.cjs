// Run against the disposable mobile fixture, never a player's saved farm.
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
(async () => {
 const browser = await chromium.launch({headless:true});
 try {
  const page = await browser.newPage({viewport:{width:1280,height:800}});
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if(message.type()==='error') errors.push(message.text()); });
  await page.addInitScript(() => {
   window.voicePeaks = [];
   const Base = window.AudioContext;
   const connect = AudioNode.prototype.connect;
   AudioNode.prototype.connect = function(destination, ...args) {
    const meter = this.context.voiceMeter;
    return connect.call(this, meter && this !== meter && destination === this.context.destination ? meter : destination, ...args);
   };
   window.AudioContext = class extends Base {
    constructor(...args) {
     super(...args);
     this.voiceMeter = this.createAnalyser();
     this.voiceMeter.fftSize = 2048;
     this.voiceMeter.connect(this.destination);
     // Meter on the audio thread: software WebGL can stall main-thread sampling
     // long enough to miss an entire half-second utterance.
     const source = `class PeakMeter extends AudioWorkletProcessor {
      process(inputs,outputs) {
       let peak=0;
       for(let c=0;c<outputs[0].length;c++) {
        const data=inputs[0][c];
        if(data) { outputs[0][c].set(data); for(const value of data) peak=Math.max(peak,Math.abs(value)); }
       }
       if(peak>0.00001)this.port.postMessage(peak);
       return true;
      }
     } registerProcessor('voice-peak-meter',PeakMeter);`;
     const url = URL.createObjectURL(new Blob([source],{type:'application/javascript'}));
     window.voiceMeterReady = this.audioWorklet.addModule(url).then(()=>{
      const meter = new AudioWorkletNode(this,'voice-peak-meter',{outputChannelCount:[2]});
      meter.port.onmessage = event => window.voicePeaks.push(event.data);
      this.voiceMeter.disconnect();
      connect.call(this.voiceMeter,meter);
      connect.call(meter,this.destination);
      URL.revokeObjectURL(url);
     });
    }
   };
  });
  await page.goto(process.env.TATER_QA_URL || 'http://127.0.0.1:8766/index.html');
  await page.waitForFunction(()=>!!window.mobileQA,null,{timeout:60000});
  await page.evaluate(()=>window.voiceMeterReady);
  const report = () => page.evaluate(()=>{window.mobileQA('status');return window.mobileReport;});
  const command = async action => {
   await page.evaluate(action=>window.mobileQA(action),action);
   await page.waitForTimeout(150);
   return report();
  };
  await page.mouse.click(600,350); // Unlock browser audio through real input.
  await command('layout:1');
  const compost = await command('compost');
  assert.equal(compost.panel,'builds');
  assert.equal(compost.build_selection,'farmer');
  assert.ok(compost.labels.includes('Compost · Farmer perk'));
  assert.ok(compost.buttons.some(button=>button.text.includes('1 compost → 3× harvest')));
  await command('close');
  const pitches = [];
  for (const id of ['mara','bram','pip']) {
   await page.evaluate(()=>{window.voicePeaks=[];});
   const start = await command('talk:'+id);
   assert.equal(start.conversation.npc,id);
   assert.equal(start.voice.speaker,id);
   pitches.push(start.voice.pitch);
   await page.waitForTimeout(1700);
   assert.ok(await page.evaluate(()=>Math.max(...window.voicePeaks)>0.001),id+' voice reaches the browser audio output');
   const after = await report();
   assert.ok(after.voice.utterances-start.voice.utterances <= 2,'chatter is bounded');
   await page.keyboard.press('Space');
   assert.equal((await report()).voice.playing,false,'reveal stops voice');
   await page.keyboard.press('Escape');
   assert.equal((await report()).voice.playing,false,'closing leaves no voice playing');
  }
  assert.ok(pitches[1]<pitches[0] && pitches[2]>pitches[0],'villagers have different vocal pitches');
  assert.deepEqual(errors,[]);
  console.log('NPC VOICE BROWSER: direct compost, audible potato clips, varied villagers and immediate stop passed');
 } finally { await browser.close(); }
})().catch(error=>{console.error(error);process.exitCode=1;});
