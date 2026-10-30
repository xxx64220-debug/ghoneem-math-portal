// Parse the real HTML before compiling: a raw closing script tag in a JS string
// terminates the element even if the full, unparsed JavaScript would be valid.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm');
const {JSDOM}=require('./english-runtime/node_modules/jsdom');
for(const dir of ['web','portal-static','dist'].filter(d=>fs.existsSync(d+'/admin.html'))){
 for(const file of fs.readdirSync(dir).filter(f=>f.endsWith('.html'))){
  test(`${dir}/${file}: parsed inline JavaScript is complete`,()=>{
   const dom=new JSDOM(fs.readFileSync(`${dir}/${file}`,'utf8'));
   try{
    for(const [i,script] of [...dom.window.document.scripts].entries()){
     if(script.src||script.type&&!['text/javascript','application/javascript'].includes(script.type))continue;
     assert.doesNotThrow(()=>new vm.Script(script.textContent,{filename:`${dir}/${file}:script-${i}`}),`HTML truncated inline script ${i}`);
    }
   }finally{dom.window.close();}
  });
 }
}
test('console has one registration script and no leaked template controls',()=>{
 const dom=new JSDOM(fs.readFileSync('web/admin.html','utf8'));
 try{
  const doc=dom.window.document;
  assert.equal(doc.querySelectorAll('script[src^="/registration-admin.js"]').length,1);
  assert.equal(doc.querySelector('input[id="${id}"]'),null);
  assert.equal(doc.querySelector('textarea[id="${id}"]'),null);
  assert.equal(doc.querySelector('select[id="${id}"]'),null);
 }finally{dom.window.close();}
});
test('hardest-question print report remains script-free and escapes question text',()=>{
 const html=fs.readFileSync('web/admin.html','utf8');
 const code=html.slice(html.indexOf('function questionPdf('),html.indexOf('// Staff authoring uses'));
 let written='',closed=false,printed=false;
 const report={document:{write:s=>written+=s,close:()=>{closed=true;}},print:()=>{printed=true;}};
 const esc=s=>String(s??'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
 const context=vm.createContext({ST:{track:'sat'},esc,alert:()=>assert.fail('unexpected alert'),setTimeout:f=>f()});
 vm.runInContext(code,context);
 context.questionPdf([{rank:1,sources:'Source',lesson:'Circles',stem:'<img src=x> Find the radius.',answered_by:4,got_it_right:1,got_it_wrong:3,percent_correct:25}],report,'sat','Current cycle');
 const dom=new JSDOM(written);
 try{
  assert(closed&&printed);
  assert.equal(dom.window.document.querySelectorAll('script,img').length,0);
  assert.equal(dom.window.document.querySelectorAll('tbody tr').length,1);
  assert.match(dom.window.document.body.textContent,/Find the radius/);
  assert.match(dom.window.document.body.textContent,/Current cycle/);
 }finally{dom.window.close();}
});
