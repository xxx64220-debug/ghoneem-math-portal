const assert=require('node:assert/strict');
const fs=require('node:fs');
const {JSDOM}=require('./passage-runtime/node_modules/jsdom');
const html=fs.readFileSync('web/index.html','utf8');
const script=fs.readFileSync('web/sat-calculator.js','utf8');
(async()=>{
 for(const mode of ['disabled','demo','authorized','failed']){
  const dom=new JSDOM(html,{runScripts:'outside-only',url:'https://portal.invalid'});
  const w=dom.window,d=w.document;let calls=0,destroyed=0;
  w.GHONEEM_DESMOS={productionAuthorized:mode!=='disabled',apiKey:mode==='demo'?'desmos':'fixture-only'};
  w.Desmos={GraphingCalculator(host){calls++;host.innerHTML='<input value="y=x">';return {resize(){},destroy(){destroyed++;host.replaceChildren()}}}};
  w.eval(script);w.SatCalculator.start(true);
  const click=id=>d.getElementById(id).click();
  click('satCalculatorToggle');assert.equal(d.getElementById('satCalculatorPanel').hidden,false);
  const sdk=d.querySelector('script[src*="www.desmos.com/api"]');
  if(mode==='disabled'||mode==='demo')assert.equal(sdk,null);
  else {sdk.dispatchEvent(new w.Event(mode==='failed'?'error':'load'));await new Promise(r=>setImmediate(r));}
  assert.equal(calls,mode==='authorized'?1:0);
  click('satCalculatorSize');assert.equal(d.getElementById('satCalculatorSize').getAttribute('aria-pressed'),'true');
  click('satCalculatorClose');assert.equal(d.activeElement.id,'satCalculatorToggle');
  click('satCalculatorToggle');
  if(mode==='authorized'){assert.equal(d.querySelector('#satCalculatorHost input').value,'y=x');assert.equal(calls,1);}
  d.getElementById('satCalculatorClose').dispatchEvent(new w.KeyboardEvent('keydown',{key:'Escape',bubbles:true}));
  assert.equal(d.getElementById('satCalculatorPanel').hidden,true);
  w.SatCalculator.start(false);assert.equal(d.getElementById('satCalculatorToggle').classList.contains('hidden'),true);
  assert.equal(destroyed,mode==='authorized'?1:0);dom.window.close();
 }
 console.log('PASS: calculator authorization gates, failure, controls, focus, persistence and attempt reset');
})().catch(e=>{console.error(e);process.exit(1)});
