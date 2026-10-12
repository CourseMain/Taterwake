const {chromium}=require('playwright');
const fs=require('node:fs');
const assert=require('node:assert/strict');
const URL=process.argv[2],out=process.argv[3];
const views=['tool_tiles','market','market_sell/russet','market_sell/giant','market_sell/golden','market_sell/sunburst','market_sell/icecap','market_undo','field_notes','accounts','year1_accounts','barn','inventory','tools','quests','menu','pause','calendar','grades','farmer','decorations','duck_patrol','dex','climate','help','farm_tip','graphics','save_page','reset_confirm','debug_locked','debug','measurement','sound','sleep_confirm','practice','sale_reveal','run_summary','foreclosure','epilogue','npc:mara','npc:nell','npc:bram','npc:tess','npc:pip','npc:iris','npc:edwin','npc:mara/story','npc:mara/reply','npc:mara/advice','npc:mara/weather','title','title_confirm','front_page','guide_exit',...Array.from({length:10},(_,i)=>'guide/'+i)];
(async()=>{
 fs.mkdirSync(out,{recursive:true});
 const browser=await chromium.launch({headless:true,ignoreDefaultArgs:['--mute-audio'],executablePath:process.env.CHROME_EXECUTABLE||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',args:['--use-angle=metal','--autoplay-policy=no-user-gesture-required']});
 const errors=[],results=[];
 try{
  const context=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
  await context.addInitScript(()=>{
   window.qolAudio={onset:null,armed:false,outputs:[],sources:[]};
   const connect=AudioNode.prototype.connect,observed=new WeakSet();
   AudioNode.prototype.connect=function(...args){
    if(args[0] instanceof AudioDestinationNode&&!observed.has(this)){
     observed.add(this);window.qolAudio.sources.push(this);
     window.qolAudio.context=this.context;
    }
    return connect.apply(this,args);
   };
   window.qolInstallAnalysers=()=>{
    for(const source of window.qolAudio.sources){
     const analyser=source.context.createAnalyser();analyser.fftSize=256;
     const silent=source.context.createGain();silent.gain.value=0;
     connect.call(source,analyser);connect.call(analyser,silent);connect.call(silent,source.context.destination);
     const output={peak:0};window.qolAudio.outputs.push(output);
     const samples=new Float32Array(256);
     setInterval(()=>{
      analyser.getFloatTimeDomainData(samples);output.peak=0;
      for(const v of samples)output.peak=Math.max(output.peak,Math.abs(v));
      window.qolAudio.peak=Math.max(...window.qolAudio.outputs.map(item=>item.peak));
      if(window.qolAudio.armed&&window.qolAudio.onset===null&&window.qolAudio.peak>0.00001)window.qolAudio.onset=performance.now();
     },2);
    }
   };
   addEventListener('pointerdown',()=>{window.qolDOMInput=performance.now();window.qolAudio.onset=null;window.qolAudio.armed=true},true);
  });
  const page=await context.newPage();page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR:|ERROR:/.test(m.text()))errors.push(m.text())});
  await page.goto(URL);await page.waitForFunction(()=>window.surfaceReport?.ready,null,{timeout:120000});
  // Observe the complete mix after Godot has finished building its audio graph.
  await page.evaluate(()=>window.qolInstallAnalysers());
  async function prepare(view){
   const previous=await page.evaluate(()=>window.surfaceReport.request);
   await page.evaluate(v=>window.surfaceQA('latency:page:'+v),view);
   await page.waitForFunction(({previous,view})=>window.surfaceReport?.ready&&window.surfaceReport.request>previous&&window.surfaceReport.page==='latency:'+view,{previous,view},{timeout:120000});
   return await page.evaluate(()=>window.surfaceReport);
  }
  for(const view of (process.env.QOL_LATENCY_VIEWS ? process.env.QOL_LATENCY_VIEWS.split(',') : views)){
   let report=await prepare(view);const targets=report.latency_buttons;
   if(!targets.length)throw new Error('No card buttons enumerated: '+view);
   for(const target of targets){
    report=await prepare(view);
    await page.evaluate(i=>window.surfaceQA('latency:target:'+i),target.index);
    await page.waitForFunction(()=>window.surfaceReport?.ready&&window.surfaceReport.latency_armed.length===4);
    report=await page.evaluate(()=>window.surfaceReport);
    const [lx,ly,lw,lh]=report.latency_armed;
    const sx=390/report.logical_size[0],sy=844/report.logical_size[1];
    const x=(lx+lw/2)*sx,y=(ly+lh/2)*sy;
    assert(x>=0&&x<390&&y>=0&&y<844,`${view} ${target.text} must be visible for a real tap: ${x},${y}`);
    await page.waitForTimeout(180);
    await page.waitForFunction(()=>window.qolAudio.peak!==undefined&&window.qolAudio.peak<0.00001,null,{timeout:5000});
    await page.evaluate(()=>{window.qolAudio.onset=null;window.qolAudio.armed=false;window.qolTap=null;window.qolDOMInput=null});
    await page.mouse.move(x,y);await page.mouse.down();await page.waitForTimeout(45);await page.mouse.up();
    await page.waitForTimeout(320);
    const timing=await page.evaluate(()=>({tap:window.qolTap,dom:window.qolDOMInput,audio:window.qolAudio.onset,peak:window.qolAudio.peak,state:window.qolAudio.context?.state,sink:window.qolAudio.context?.sinkId,audio_error:window.qolAudio.error,game:window.qolSound}));
    const visual=timing.tap?timing.tap.paint-timing.dom:null;
    const sound=timing.audio===null?null:timing.audio-timing.dom;
    results.push({view,...target,visual_ms:visual,sound_ms:sound,diagnostic:timing});
    if(process.env.QOL_LATENCY_BASELINE!=='1'){
     assert(visual!==null&&visual>=0&&visual<=100,`${view} ${target.text}: visible feedback ${visual} ms`);
     assert(sound!==null&&sound>=0&&sound<=300,`${view} ${target.text}: audible feedback ${sound} ms`);
    }
   }
   console.log(view+': '+targets.length+' real button taps');
   if(view==='tool_tiles'){await prepare(view);await page.screenshot({path:out+'/tool-tiles-390.png'})}
  }
  assert.deepEqual(errors,[]);
  console.log('TAP LATENCY: '+results.length+' checks, 0 failures; slowest visual '+Math.max(...results.map(x=>x.visual_ms||0)).toFixed(2)+' ms; sound '+Math.max(...results.map(x=>x.sound_ms||0)).toFixed(2)+' ms');
 }finally{fs.writeFileSync(out+'/latency.json',JSON.stringify({results,errors,limits_ms:{visual:100,sound:300}},null,2)+'\n');await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
