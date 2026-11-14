const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const {JSDOM}=require('./english-runtime/node_modules/jsdom');
const render=require('./english-runtime/node_modules/katex/dist/contrib/auto-render');
const dir='content-releases/20261114_bank_review/',load=n=>JSON.parse(fs.readFileSync(dir+n+'.json','utf8'));
const m=load('manifest'),pool=new Map([...load('full_candidates'),...load('full_repairs')].map(q=>[q.id,q]));
const repaired=m.updates.filter(p=>Object.keys(p.fields).length||p.assets_remove.length).map(p=>({...pool.get(p.id),...p.fields,explanation:p.fields.explanation||pool.get(p.id).key_row.explanation}));
const questions=[...repaired,...m.additions,...load('manifest_supported').additions],dom=new JSDOM('<main></main>',{runScripts:'outside-only'});
global.document=dom.window.document;global.Node=dom.window.Node;
const c=dom.getInternalVMContext(),errors=[];
c.renderMathInElement=(el,options)=>render(el,{...options,throwOnError:true,strict:'error',errorCallback:(msg,e)=>errors.push(String(e))});
vm.runInContext(fs.readFileSync('web/portal-math.js','utf8'),c);
const html=fs.readFileSync('web/index.html','utf8');
vm.runInContext(html.slice(html.indexOf('function math(el)'),html.indexOf('const FRIENDLY')),c);
let fields=0;
for(const q of questions){
 for(const value of [q.stem,q.explanation,...q.choices.map(c=>c.text)]){
  const el=c.document.querySelector('main');el.textContent=value;c.math(el);fields++;
  assert.equal(el.querySelector('.katex-error'),null,q.id);
  assert.equal(el.querySelector('script,img'),null,q.id);
  const before=el.innerHTML;c.math(el);assert.equal(el.innerHTML,before,'Repeated rendering must be stable');
  if(/\\(?:frac|sqrt|log)/.test(value))assert.ok(el.querySelector('.katex'),'Explicit math must actually render: '+value);
 }
}
assert.deepEqual(errors,[]);
const p=m.updates.find(p=>p.id==='2574795c-0842-5799-a7a6-9f318be55de6');
const graphic=new JSDOM(p.assets_merge.svg,{contentType:'image/svg+xml'});
assert.equal(graphic.window.document.querySelector('parsererror'),null);
assert.ok(graphic.window.document.documentElement.getAttribute('viewBox'));
assert.ok(graphic.window.document.documentElement.getAttribute('aria-label'));
assert.equal(graphic.window.document.querySelector('script,image,foreignObject'),null);
fs.writeFileSync(dir+'reviewed-angle.svg',p.assets_merge.svg);
console.log(`${fields} content fields passed the portal math renderer; diagram markup passed`);
