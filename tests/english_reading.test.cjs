const {test}=require('node:test');
const assert=require('node:assert/strict');
const {readFileSync}=require('node:fs');
const vm=require('node:vm');
const {JSDOM}=require('./english-runtime/node_modules/jsdom');
const html=readFileSync('web/index.html','utf8');
const original=html.slice(0,html.indexOf('function renderQ()'))+readFileSync('tests/fixtures/pre-english-renderQ.js','utf8')+html.slice(html.indexOf('/* Lane A'));
function setup(source=html){
 const dom=new JSDOM('<div id="qcard"></div><button id="prevBtn"></button><button id="nextBtn"></button><button id="flagBtn"></button><div id="vReview"></div>',{runScripts:'outside-only'});
 const c=dom.getInternalVMContext();
 Object.assign(c,{setInterval(){},ST:{run:{exam:{track_id:'est_eng'},questions:[]},track:{id:'est_eng'},idx:0,flags:new Set()},esc:s=>String(s??'').replaceAll('&','&amp;').replaceAll('"','&quot;').replaceAll('<','&lt;').replaceAll('>','&gt;'),$:id=>dom.window.document.getElementById(id),math(){},reportButton:()=>'',save(q,value){q.response=value},fmt:String,show(){},openTrack(){},setDashboardView(){},DASH:{notebookFeedback:{}}});
 vm.runInContext(source.slice(source.indexOf('function ent(t)'),source.indexOf('const fmt =')),c);
 if(source.includes('function englishPassage'))vm.runInContext(source.slice(source.indexOf('function englishPassage'),source.indexOf('function renderQ')),c);
 vm.runInContext(source.slice(source.indexOf('function renderQ()'),source.indexOf('/* Lane A')),c);
 vm.runInContext(source.slice(source.indexOf('function paintReview('),source.indexOf('/* ---------------- figure rendering')),c);
 vm.runInContext(readFileSync('web/daily-challenge.js','utf8'),c);
 return c;
}
const passage='<div class="est-passage" style="max-height:1px"><div>Module 2 · Passage 1</div><div>Title</div><div>by Author</div><p>First paragraph.</p><p><b>[2]</b> <u>Underlined text</u> <mark>[3]</mark><br>Next line.</p><figure><img src="data:image/png;base64,aGVsbG8=" alt="Snake"><figcaption>Original caption</figcaption></figure></div>';
const question={id:'english-1',type:'mcq',stem:'Which statement is supported?\nChoose one.',topic:'Reading',choices:[{key:'A',text:'First'},{key:'B',text:'Second'}],assets:{html:passage,passage_title:'Title',passage_number:1,module:2}};
test('real import shape preserves paragraphs, annotations, illustration and answer controls',()=>{
 const c=setup();c.ST.run.questions=[structuredClone(question)];c.renderQ();
 const doc=c.document;
 assert.equal(doc.querySelectorAll('.est-passage p').length,2);
 assert.equal(doc.querySelector('u').textContent,'Underlined text');
 assert.equal(doc.querySelector('mark').textContent,'[3]');
 assert.equal(doc.querySelector('img').alt,'Snake');
 assert.equal(doc.querySelector('figcaption').textContent,'Original caption');
 assert.equal(doc.querySelectorAll('.est-passage').length,1);
 const details=doc.querySelector('details');assert.equal(details.open,true);details.open=false;assert.equal(details.open,false);
 assert.equal(doc.querySelector('.english-question-pane .stem').textContent,question.stem);
 doc.querySelector('[data-k="B"]').click();assert.equal(c.ST.run.questions[0].response,'B');
 assert.equal(doc.querySelector('.est-passage [style]'),null);
});
test('uncertain boundaries stay unsplit and all math tracks retain original exam markup',()=>{
 const c=setup();
 for(const assets of [null,{html:'<p>Unmarked long passage?</p>'},{html:'<div class="est-passage">Passage</div><p>Other context</p>'},{html:'Extra text<div class="est-passage">Passage</div>'}]){
  const q={...question,assets};assert.equal(c.englishPassage(q,'est_eng'),'');
  assert.equal(c.readingQuestion(q,'est_eng','answers'),`<div class="stem">${c.esc(q.stem)}</div>`+c.figure(assets)+'answers');
 }
 const before=setup(original);
 for(const track of ['sat','est','est2']){
  for(const ctx of [c,before]){ctx.ST.run.exam.track_id=track;ctx.ST.track.id=track;ctx.ST.run.questions=[structuredClone(question)];ctx.renderQ();}
  assert.equal(c.document.getElementById('qcard').innerHTML,before.document.getElementById('qcard').innerHTML);
  assert.equal(c.englishPassage(question,track),'');
 }
});
test('passage sanitizer removes executable markup and unsafe images without touching source',()=>{
 const c=setup();const q=structuredClone(question);q.assets.html=passage.replace('</div>','<script>alert(1)</script></div>').replace('<u>','<u onclick="alert(1)">')+' ';
 q.assets.html=q.assets.html.replace('</figure>','<img src="javascript:alert(1)" onerror="alert(1)"><iframe src="https://bad.test"></iframe></figure>');
 const snapshot=JSON.stringify(q);const out=c.englishPassage(q,'est_eng');
 assert.ok(out.includes('<u>'));assert.doesNotMatch(out,/script|onclick|onerror|iframe|javascript:|style=/i);assert.equal(JSON.stringify(q),snapshot);
});
test('exam review, notebook, daily quiz and drill use the passage layout',()=>{
 const c=setup();
 c.paintReview({exam:{track_id:'est_eng'},attempt:{score:1,total:1},review_open:true,items:[{...question,correct:'A',response:'B',explanation:'Reason',is_correct:false}]});
 assert.ok(c.document.querySelector('.english-question-pane .review-choices'));
 for(const [field,method,value] of [
  ['mistakes','mistakesPanel',{remaining:1,mastered:0,items:[{...question,streak:0}]}],
  ['drill','drillPanel',{drill_id:'drill',topics:['Reading'],completed:false,questions:[question]}],
  ['daily','dailyPanel',{track:'est_eng',quiz:[question],checklist:{},leaderboard:[],completed:false,reset_at:new Date().toISOString(),streak:null}]
 ]){c.DASH[field]=value;const out=c[method]();assert.match(out,/english-reading/);assert.equal((out.match(/class="est-passage"/g)||[]).length,1);assert.doesNotMatch(out,/Correct answer:/);}
});
test('deployed copies and responsive styles stay consistent',()=>{
 for(const file of ['index.html','daily-challenge.js','english-reading.css'])assert.equal(readFileSync('web/'+file,'utf8'),readFileSync('dist/'+file,'utf8'));
 const css=readFileSync('web/english-reading.css','utf8');assert.match(css,/max-width:65ch/);assert.match(css,/@media\(max-width:850px\)/);assert.match(css,/max-height:none;overflow:visible/);
});
