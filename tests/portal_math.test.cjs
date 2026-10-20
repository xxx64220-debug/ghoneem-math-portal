const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const {JSDOM}=require('./english-runtime/node_modules/jsdom');
const autoRender=require('./english-runtime/node_modules/katex/dist/contrib/auto-render.js');
const read=p=>fs.readFileSync(p,'utf8');
const html=read('web/index.html');
const screenshot='A math book costs $75. An English book costs 40% less. One math book, one English book, and 3 copybooks cost $153. What is the combined cost of the 3 copybooks?';
const esc=s=>String(s??'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));

function setup(){
 const dom=new JSDOM('<main></main><div id="qcard"></div><button id="prevBtn"></button><button id="nextBtn"></button><button id="flagBtn"></button><dialog id="editor"></dialog><div id="vReview"></div>',{runScripts:'outside-only'});
 const c=dom.getInternalVMContext(),errors=[];
 global.document=dom.window.document;global.Node=dom.window.Node;
 Object.assign(c,{esc,fmt:String,$:id=>c.document.getElementById(id),setInterval(){},ST:{track:{id:'est'},run:{exam:{track_id:'est'},questions:[]},idx:0,flags:new Set()},DASH:{notebookFeedback:{}},reportButton:()=>'',save(q,v){q.response=v},show(){},openTrack(){},setDashboardView(){}});
 c.renderMathInElement=(el,options)=>{c.mathOptions=options;autoRender(el,{...options,throwOnError:true,strict:'error',errorCallback:(_message,error)=>errors.push(String(error))});};
 vm.runInContext(read('web/portal-math.js'),c);
 vm.runInContext(html.slice(html.indexOf('function math(el)'),html.indexOf('const FRIENDLY')),c);
 return {c,dom,errors};
}

test('the reported PSD 133:Q24 sentence retains every price, word and percent',()=>{
 const {c,errors}=setup(),el=c.document.querySelector('main');el.textContent=screenshot;
 c.math(el);
 assert.equal(el.textContent,screenshot);
 assert.equal(el.querySelector('.katex'),null);
 assert.deepEqual(errors,[]);
 assert.equal(153-75-75*.6,33);
});

test('prices, decimals, escaped dollars and arithmetic with several prices stay literal',()=>{
 const {c,errors}=setup(),el=c.document.querySelector('main');
 for(const [source,expected] of [
  ['$5 and $10','$5 and $10'],['$5 + $3 = $8','$5 + $3 = $8'],
  ['$1,250.50, then $230.75.','$1,250.50, then $230.75.'],
  ['$0.30 per article and $15 each month.','$0.30 per article and $15 each month.'],
  ['Pay \\$75 and $153.','Pay $75 and $153.'],
  ['$5 for a pen; $10 for a book.','$5 for a pen; $10 for a book.'],
  ['$5 for a pen; use $x+1$ for its model.',null],
 ]){
  el.textContent=source;c.math(el);
  if(expected!==null){assert.equal(el.textContent,expected);assert.equal(el.querySelector('.katex'),null,source);}
  else{assert.ok(el.textContent.startsWith('$5 for a pen; use '));assert.equal(el.querySelectorAll('.katex').length,1);}
 }
 assert.deepEqual(errors,[]);
 for(const source of ['$10 + $x+1$','$10, $x+1$','$10 $x+1$']){
  el.textContent=source;c.math(el);assert.ok(el.textContent.startsWith(source.slice(0,source.indexOf('$x'))));assert.equal(el.querySelectorAll('.katex').length,1,source);
 }
 assert.deepEqual(errors,[]);
});

test('explicit and legacy formulas still render next to literal currency, including matrices',()=>{
 const {c,errors}=setup(),el=c.document.querySelector('main');
 const formulas=[String.raw`\(x+1=3\)`,String.raw`\[\frac{1}{2}\]`,String.raw`$$x^2=9$$`,String.raw`$\frac{2x^2+12x+c}{3}$`,String.raw`$100c+50cm$`,String.raw`$5$`,String.raw`$\text{Total cost}=\$75$`,String.raw`$\begin{pmatrix}1&2\\3&4\end{pmatrix}$`];
 for(const formula of formulas){
  el.textContent='Pay $75 and $153; solve '+formula+'.';c.math(el);
  assert.ok(el.textContent.startsWith('Pay $75 and $153; solve '),formula);
  assert.equal(el.querySelectorAll('.katex').length,1,formula);
  const before=el.innerHTML;c.math(el);assert.equal(el.innerHTML,before,'repeat rendering is safe');
 }
 assert.deepEqual(errors,[]);
 assert.equal(c.mathOptions.trust,false);assert.equal(c.mathOptions.maxExpand,1000);assert.equal(c.mathOptions.maxSize,20);
 assert.ok(!c.mathOptions.delimiters.some(d=>d.left==='$'));
});

test('table cells, choice spans and already-rendered or ignored content stay safe',()=>{
 const {c,errors}=setup(),el=c.document.querySelector('main');
 el.innerHTML='<table><tr><td>$75</td><td>$153</td></tr></table><span>$11</span><span>$33</span><code>$x+1$</code><svg><text>$5</text></svg>';
 const before=el.innerHTML;c.math(el);assert.equal(el.innerHTML,before);assert.deepEqual(errors,[]);
 el.textContent='Pay $5 and $10. <img src=x onerror=alert(1)>';c.math(el);
 assert.equal(el.querySelector('img,script'),null);
 assert.equal(el.textContent,'Pay $5 and $10. <img src=x onerror=alert(1)>');
});

test('all student exam tracks, review, daily practice, notebook and drills use the protected renderer',()=>{
 const {c,errors}=setup();
 vm.runInContext(html.slice(html.indexOf('function ent(t)'),html.indexOf('const fmt =')),c);
 vm.runInContext(html.slice(html.indexOf('function englishPassage'),html.indexOf('function renderQ')),c);
 vm.runInContext(html.slice(html.indexOf('function renderQ()'),html.indexOf('/* Lane A')),c);
 const reviewStart=html.includes('function reviewBody(')?html.indexOf('function reviewBody('):html.indexOf('function paintReview(');
 vm.runInContext(html.slice(reviewStart,html.indexOf('/* ---------------- figure rendering')),c);
 vm.runInContext(read('web/daily-challenge.js'),c);
 const question={id:'screenshot',type:'mcq',topic:'Percentages',stem:screenshot,assets:{},choices:[{key:'A',text:'$11'},{key:'B',text:'$33'},{key:'C',text:'$4'},{key:'D',text:'$66'}]};
 for(const track of ['sat','est','est2']){
  c.ST.track.id=track;c.ST.run.exam.track_id=track;c.ST.run.questions=[structuredClone(question)];c.renderQ();
  const card=c.document.getElementById('qcard');assert.equal(card.querySelector('.stem').textContent,screenshot);assert.equal(card.querySelector('.katex'),null);
  card.querySelector('[data-k="B"]').click();assert.equal(c.ST.run.questions[0].response,'B');
 }
 c.paintReview({exam:{track_id:'est'},attempt:{score:1,total:1},review_open:true,items:[{...question,correct:'B',response:'B',explanation:'The books cost $120. The copybooks cost $33.',is_correct:true}]});
 const review=c.document.getElementById('vReview');assert.ok(review.textContent.includes(screenshot));assert.ok(review.textContent.includes('The books cost $120. The copybooks cost $33.'));assert.equal(review.querySelector('.katex'),null);
 for(const [field,method,value] of [
  ['mistakes','mistakesPanel',{remaining:1,mastered:0,items:[{...question,streak:0}]}],
  ['drill','drillPanel',{drill_id:'drill',topics:['Percentages'],completed:false,questions:[question]}],
  ['daily','dailyPanel',{track:'est',quiz:[question],checklist:{},leaderboard:[],completed:false,reset_at:new Date().toISOString(),streak:null}],
 ]){c.DASH[field]=value;const el=c.document.querySelector('main');el.innerHTML=c[method]();c.math(el);assert.ok(el.textContent.includes(screenshot),method);assert.equal(el.querySelector('.katex'),null,method);}
 assert.deepEqual(errors,[]);
});

test('staff bank previews and instructor answer reveal retain readable prices',async()=>{
 const {c,errors}=setup();
 vm.runInContext(read('web/instructor-practice.js'),c);vm.runInContext(read('web/exam-builder.js'),c);
 const el=c.document.querySelector('main');el.textContent=screenshot;c.renderQuestionMath(el);assert.equal(el.textContent,screenshot);assert.equal(el.querySelector('.katex'),null);
 const q={id:'q',stem:screenshot,type:'mcq',choices:[{key:'B',text:'$33'}],assets:{}};
 c.sb={from:table=>({select:()=>({in:async()=>({data:table==='questions'?[q]:[{question_id:'q',correct:'B',explanation:'The books cost $120 and the copybooks cost $33.'}]})})})};
 c.alert=message=>{throw Error(message);};c.document.getElementById('editor').showModal=()=>{};
 await c.openTeachingExam({title:'Preview',question_ids:['q']});
 assert.equal(c.document.querySelector('.teaching-question').textContent,screenshot);
 c.document.getElementById('teachReveal').onclick();assert.ok(c.document.querySelector('.teaching-answer').textContent.includes('The books cost $120 and the copybooks cost $33.'));assert.equal(c.document.getElementById('editor').querySelector('.katex'),null);
 assert.deepEqual(errors,[]);
});

test('both pages load the same helper before application code, and its packaged copy matches',()=>{
 for(const path of ['web/index.html','web/admin.html']){
  const page=read(path);assert.match(page,/<script src="\/portal-math\.js\?v=20261021-currency"><\/script>/);
  assert.ok(page.indexOf('/portal-math.js')<page.indexOf('const SB_URL'));
 }
 if(fs.existsSync('portal-static'))assert.equal(read('web/portal-math.js'),read('portal-static/portal-math.js'));
 if(fs.existsSync('dist/index.html'))assert.equal(read('web/portal-math.js'),read('dist/portal-math.js'));
 for(const file of fs.readdirSync('web').filter(name=>/\.(?:js|html)$/.test(name)&&name!=='portal-math.js')){
  assert.doesNotMatch(read('web/'+file),/renderMathInElement\s*\(/,file+' must use the shared renderer');
 }
});
