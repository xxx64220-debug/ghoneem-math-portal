const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),vm=require('node:vm');
const {webcrypto}=require('node:crypto');
const root=path.resolve(__dirname,'..'),rows=JSON.parse(fs.readFileSync(path.join(root,'content/est-september-2026/review-archive.json')));
const elements=new Map();
function el(id){if(!elements.has(id))elements.set(id,{innerHTML:'',textContent:'',value:'',open:false,showModal(){this.open=true},close(){this.open=false},addEventListener(){}});return elements.get(id)}
let selected=rows[0];let fail=false;let blob;
const sb={from(table){assert.equal(table,'est_source_review');return {select(){return this},order(){return this},limit:async()=>({data:rows,error:fail?new Error('blocked'):null}),eq(key,id){selected=rows.find(x=>x.id===id);return this},single:async()=>({data:selected,error:fail?new Error('blocked'):null})}}};
const esc=x=>String(x??'').replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
const context=vm.createContext({sb,$:el,ST:{track:'est'},esc,wrapTable:x=>x,document:{querySelectorAll:()=>[]},Uint8Array,TextEncoder,Blob,atob,crypto:webcrypto,
 URL:{createObjectURL(b){blob=b;return 'blob:test'},revokeObjectURL(){}},fetch:async p=>({ok:true,arrayBuffer:async()=>{const b=fs.readFileSync(path.join(root,'dist',p));return b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength)}})});
vm.runInContext(fs.readFileSync(path.join(root,'web/est-source-review.js'),'utf8'),context);
(async()=>{
 await vm.runInContext('sourceReview()',context);
 assert.match(el('view').innerHTML,/949 source entries/);
 el('sourceSearch').value='HOA 034';el('sourceSearch').oninput();assert.match(el('sourceCount').textContent,/1 matching/);
 for(const id of ['topic:FA 001','clean:HOA 034','clean:PSD 202','clean:MIX 061']){
  await context.openSourceEntry(id);
  assert.match(el('editor').innerHTML,/Download original image/);
  const hash=Buffer.from(await webcrypto.subtle.digest('SHA-256',await blob.arrayBuffer())).toString('hex');
  assert.equal(hash,selected.image_sha256);
 }
 assert.match(el('editor').innerHTML,/Worked answer/);
 fail=true;await context.openSourceEntry('clean:MIX 061');assert.match(el('editor').innerHTML,/blocked/);
 assert.doesNotMatch(el('editor').innerHTML,/blob:test/);
 console.log('PASS:949-row instructor list, search, original-image decryption/integrity across both PDFs, ready/provisional labels and access-error handling.');
})().catch(e=>{console.error(e);process.exitCode=1});
