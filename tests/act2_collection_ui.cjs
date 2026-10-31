const {JSDOM}=require('./english-runtime/node_modules/jsdom'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
async function main(){
 const dom=new JSDOM('<main id="view"></main><dialog id="editor"></dialog>',{runScripts:'outside-only',url:'https://math.portal.ghoneem.com/admin.html'}),c=dom.getInternalVMContext(),modal=dom.window.document.querySelector('dialog');
 modal.showModal=()=>{modal.open=true;};modal.close=()=>{modal.open=false;modal.dispatchEvent(new dom.window.Event('close'));};
 const doc={id:'doc',filename:'Graph <img src=x onerror=alert(1)>.pdf',category:'Questions',subject:'Math 1',notes:'Original source',page_count:2,size_bytes:1024,matching_pages:[2],source_url:'https://www.act.org/content/practice.pdf'};
 let selected='';
 Object.assign(c,{$:id=>dom.window.document.getElementById(id),ST:{track:'act2'},esc:s=>String(s??'').replace(/[&<>"']/g,x=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[x])),wrapTable:s=>s,pagedQuestionBank:()=>{},sb:{rpc:async()=>({data:[doc]}),from:()=>({select:s=>{selected=s;return {eq:()=>({single:async()=>({data:doc})})};}})}});
 vm.runInContext(fs.readFileSync('web/act2-collection.js','utf8'),c);
 await c.act2Collection();assert.equal(dom.window.document.querySelectorAll('[data-act2-doc]').length,1);assert.equal(dom.window.document.querySelectorAll('img').length,0);
 await c.openAct2Document('doc',2);assert.equal(modal.querySelector('a').href,doc.source_url+'#page=2');assert(!selected.includes('download_manifest'));assert.equal(modal.querySelectorAll('img').length,0);
 for(const source of ['https://drive.google.com/file/d/example/view','https://chatgpt.com/library?file_id=example&account_id=personal']){doc.source_url=source;await c.openAct2Document('doc',2);assert.equal(modal.querySelector('a').href,source);}
 for(const source of ['javascript:alert(1)','https://evil.example/file.pdf','https://www.act.org.evil.example/file.pdf']){doc.source_url=source;await c.openAct2Document('doc');assert(modal.querySelector('[role=alert]'));assert(!modal.querySelector('a'));}
 assert(fs.readFileSync('web/admin-bank.js','utf8').includes("['est','act2'].includes(track)"));
 dom.window.close();console.log('PASS: escaped filenames, official PDF page links, original Drive/ChatGPT links, source URL validation, no key retrieval, source archive access.');
}main().catch(e=>{console.error(e);process.exitCode=1;});
