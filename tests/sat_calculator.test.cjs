const assert=require('node:assert/strict');
const fs=require('node:fs');
const {test}=require('node:test');
const {JSDOM}=require('./passage-runtime/node_modules/jsdom');
const html=fs.readFileSync('web/index.html','utf8'),script=fs.readFileSync('web/sat-calculator.js','utf8');
function setup(){const dom=new JSDOM(html,{runScripts:'outside-only',url:'https://portal.invalid/?study_exam=private-attempt'}),w=dom.window,d=w.document;w.eval(script);return {dom,w,d,click:id=>d.getElementById(id).click()};}
test('SAT exposes a lazy, isolated official website frame without an API key',()=>{
 const {dom,w,d,click}=setup();w.SatCalculator.start(true);
 assert(!d.getElementById('satCalculatorToggle').classList.contains('hidden'));
 assert.equal(d.querySelector('#satCalculatorHost iframe'),null);
 assert.equal(d.querySelector('script[src*="sat-calculator-config"]'),null);
 click('satCalculatorToggle');const frame=d.getElementById('satDesmosFrame');
 assert.equal(frame.src,'https://www.desmos.com/testing/collegeboard/graphing');
 assert.equal(frame.referrerPolicy,'no-referrer');assert.match(frame.title,/SAT Desmos/);
 assert.match(frame.getAttribute('sandbox'),/allow-scripts/);assert(!frame.getAttribute('sandbox').includes('allow-top-navigation'));
 assert(!d.getElementById('satCalculatorPanel').hidden);
 assert.equal(d.querySelector('script[src*="desmos.com/api"]'),null);
 dom.window.close();
});
test('close, reopen and resize retain the same frame without touching exam state',()=>{
 const {dom,w,d,click}=setup();w.SatCalculator.start(true);d.getElementById('saving').textContent='All answers saved';d.getElementById('clock').textContent='34:52';
 click('satCalculatorToggle');const frame=d.getElementById('satDesmosFrame');
 click('satCalculatorSize');assert.equal(d.getElementById('satCalculatorSize').getAttribute('aria-pressed'),'true');
 click('satCalculatorClose');assert(d.getElementById('satCalculatorPanel').hidden);assert.equal(d.activeElement.id,'satCalculatorToggle');
 click('satCalculatorToggle');assert.equal(d.getElementById('satDesmosFrame'),frame);
 d.getElementById('satCalculatorClose').dispatchEvent(new w.KeyboardEvent('keydown',{key:'Escape',bubbles:true}));assert(d.getElementById('satCalculatorPanel').hidden);
 assert.equal(d.getElementById('clock').textContent,'34:52');assert.equal(d.getElementById('saving').textContent,'All answers saved');
 dom.window.close();
});
test('new attempts reset the calculator and non-SAT attempts cannot load it',()=>{
 const {dom,w,d,click}=setup();w.SatCalculator.start(true);click('satCalculatorToggle');const old=d.getElementById('satDesmosFrame');
 w.SatCalculator.start(true);assert.equal(d.querySelector('#satCalculatorHost iframe'),null);click('satCalculatorToggle');assert.notEqual(d.getElementById('satDesmosFrame'),old);
 w.SatCalculator.start(false);assert(d.getElementById('satCalculatorToggle').classList.contains('hidden'));assert.equal(d.getElementById('satDesmos'),null);
 click('satCalculatorToggle');assert.equal(d.querySelector('#satCalculatorHost iframe'),null);assert(d.getElementById('satCalculatorPanel').hidden);
 dom.window.close();
});
test('load errors and slow connections offer an in-page reload',()=>{
 const {dom,w,d,click}=setup();let timeoutCallback;w.setTimeout=callback=>{timeoutCallback=callback;return 1;};w.clearTimeout=()=>{};
 w.SatCalculator.start(true);click('satCalculatorToggle');timeoutCallback();assert.match(d.getElementById('satCalculatorStatus').textContent,/taking longer/);
 const frame=d.getElementById('satDesmosFrame');frame.dispatchEvent(new w.Event('error'));assert.match(d.getElementById('satCalculatorStatus').textContent,/could not load/);
 frame.dispatchEvent(new w.Event('load'));assert.match(d.getElementById('satCalculatorStatus').textContent,/close and reopen/);
 assert.equal(d.querySelector('#satCalculatorPanel a[target]'),null);assert.equal(d.getElementById('satCalculatorRetry').hidden,false);click('satCalculatorRetry');assert.notEqual(d.getElementById('satDesmosFrame'),frame);assert.equal(d.getElementById('satDesmosFrame').src,frame.src);
 w.SatCalculator.start(false);const text=d.getElementById('satCalculatorStatus').textContent;frame.dispatchEvent(new w.Event('error'));assert.equal(d.getElementById('satCalculatorStatus').textContent,text);
 dom.window.close();
});

test('popup keeps the question interactive and keyboard moves do not reach exam shortcuts',()=>{
 const {dom,w,d,click}=setup();Object.defineProperty(w,'innerWidth',{value:390,writable:true});w.SatCalculator.start(true);click('satCalculatorToggle');
 const panel=d.getElementById('satCalculatorPanel'),handle=d.getElementById('satCalculatorTitle');let shortcuts=0;
 d.addEventListener('keydown',()=>shortcuts++);panel.getBoundingClientRect=()=>({left:8,top:300,width:374,height:500});
 assert.equal(panel.getAttribute('aria-modal'),'false');assert(!d.getElementById('qcard').closest('[inert]'));assert.equal(d.body.style.overflow,'');
 handle.dispatchEvent(new w.KeyboardEvent('keydown',{key:'ArrowRight',bubbles:true,cancelable:true}));assert.equal(shortcuts,0);assert.equal(panel.style.left,'8px');
 assert(!d.getElementById('satDesmosFrame').getAttribute('sandbox').includes('allow-popups'));
 dom.window.close();
});
