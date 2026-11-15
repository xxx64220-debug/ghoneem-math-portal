const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {JSDOM}=require('./english-runtime/node_modules/jsdom');
const html=fs.readFileSync('web/index.html','utf8');
function loadModule(path){const c={module:{exports:{}}};vm.runInNewContext(fs.readFileSync(path,'utf8'),c);return c.module.exports;}
function fixture(){
 const dom=new JSDOM(html,{url:'https://portal.invalid',runScripts:'outside-only',pretendToBeVisual:true}),w=dom.window,d=w.document,calls=[],saved=new Map(),intervals=[];let now=1000,visibility='visible';
 w.eval=code=>vm.runInContext(code,dom.getInternalVMContext());
 w.setInterval=(fn,ms)=>{intervals.push({fn,ms});return intervals.length;};w.clearInterval=()=>{};w.scrollTo=()=>{};w.alert=()=>{};w.confirm=()=>true;w.reportButton=()=>'';
 Object.defineProperty(w.performance,'now',{value:()=>now});Object.defineProperty(d,'visibilityState',{get:()=>visibility});
 w.HTMLDialogElement.prototype.showModal=function(){this.open=true;};w.HTMLDialogElement.prototype.close=function(){this.open=false;this.dispatchEvent(new w.Event('close'));};
 w.PortalSession={restore:async()=>null};
 w.supabase={createClient:()=>({auth:{getSession:async()=>({data:{session:null}}),getUser:async()=>({data:{user:null}})},from:table=>({select(){return this;},eq(){return this;},then(resolve){resolve({data:[...saved.values()],error:null});},async upsert(rows){calls.push({table,rows});if(table==='attempt_annotations')for(const row of rows)saved.set(row.question_id,structuredClone(row));return {error:null};}})})};
 w.eval(html.split('<script>')[1].split('</script>')[0]);w.removeEventListener('DOMContentLoaded',w.boot);
 w.eval('displayStudyObjective=async()=>{};');
 w.eval(fs.readFileSync('web/sat-calculator.js','utf8'));w.eval(fs.readFileSync('web/exam-experience.js','utf8'));
 const run={attempt:{id:'test-attempt',deadline_at:new Date(Date.now()+2100000).toISOString(),server_now:new Date().toISOString()},exam:{id:'test-exam',track_id:'sat'},questions:[{id:'q1',topic:'Algebra',stem:'Solve.',type:'mcq',choices:[{key:'A',text:'2'},{key:'B',text:'3'}],response:'A'},{id:'q2',topic:'Algebra',stem:'Enter x.',type:'grid_in',response:null}]};
 const start=async(transfer=false)=>{w.testRun=structuredClone(run);await w.eval(`ST.track={id:'sat'};ST.run=testRun;ST.idx=0;restoreExamFlags();ST.accessBlocked=false;show('vRun');SatCalculator.start(true);ExamExperience.start(ST.run,${transfer})`);w.eval('renderQ();renderPalette()');};
 return {dom,w,d,run,calls,saved,intervals,start,eval:s=>w.eval(s),advance:n=>now+=n,visibility:v=>{visibility=v;d.dispatchEvent(new w.Event('visibilitychange'));}};
}
test('elimination clears the selected response, survives refresh, and keeps answer writes separate',async()=>{
 const f=fixture(),resumed=fixture();try{
  await f.start();f.d.querySelector('[data-eliminate="A"]').click();await f.eval('flushAnswers()');await f.w.ExamExperience.flush();
  assert.equal(f.eval('ST.run.questions[0].response'),'');assert(f.d.querySelector('.choice-row.is-eliminated'));
  assert.equal(f.calls.find(x=>x.table==='attempt_answers').rows.response,null);
  const storage=f.w.localStorage.getItem('ghoneem-exam-tools:test-attempt');resumed.w.localStorage.setItem('ghoneem-exam-tools:test-attempt',storage);resumed.run.questions[0].response='';await resumed.start();
  assert(resumed.d.querySelector('.choice-row.is-eliminated'));resumed.d.querySelector('[data-k="A"]').click();assert(!resumed.d.querySelector('.choice-row.is-eliminated'));
  assert.equal(resumed.eval('ST.run.questions[0].response'),'A');await resumed.eval('flushAnswers()');await resumed.w.ExamExperience.flush();
 }finally{f.dom.window.close();resumed.dom.window.close();}
});
test('flag SVG stays stable across toggles, answers, question navigation and review',async()=>{
 const f=fixture();try{
  await f.start();const button=f.d.getElementById('flagBtn'),icon=button.querySelector('svg.flag-icon');
  assert(icon);assert.equal(icon.getAttribute('aria-hidden'),'true');
  button.click();assert.equal(button.querySelector('svg'),icon);assert.equal(button.getAttribute('aria-pressed'),'true');
  f.d.querySelector('[data-k="B"]').click();assert.equal(button.querySelector('svg'),icon);
  f.w.ExamExperience.review();assert(f.d.querySelector('#examReviewSheet .pal.flagged svg.flag-icon'));
  f.d.querySelector('#examReviewSheet [data-close]').click();f.d.getElementById('nextBtn').click();
  assert.equal(button.getAttribute('aria-pressed'),'false');assert.equal(button.querySelector('svg'),icon);
  f.d.getElementById('prevBtn').click();assert.equal(button.getAttribute('aria-pressed'),'true');
  button.click();assert.equal(button.getAttribute('aria-pressed'),'false');assert.equal(button.querySelector('svg'),icon);
  assert(!f.d.querySelector('#palette .pal.flagged'));assert(!button.textContent.includes('⚑'));
  await f.eval('flushAnswers()');await f.w.ExamExperience.flush();
 }finally{f.dom.window.close();}
});
test('active question time excludes hidden tabs and reference sheets and resumes on close',async()=>{
 const f=fixture();try{
  await f.start();f.advance(3000);f.visibility('hidden');f.advance(10000);f.visibility('visible');f.advance(2000);f.d.getElementById('referenceBtn').click();f.advance(12000);f.d.querySelector('#examReferenceSheet [data-close]').click();f.advance(1000);f.w.ExamExperience.accrue();await f.w.ExamExperience.flush();
  assert.equal(f.saved.get('q1').seconds,6);assert.equal(f.eval('ST.run.questions[0].response'),'A');
 }finally{f.dom.window.close();}
});
test('review counts distinguish blanks and flags; shortcuts pause for numeric entry and dialogs',async()=>{
 const f=fixture();try{
  await f.start();const key=(target,k)=>target.dispatchEvent(new f.w.KeyboardEvent('keydown',{key:k,bubbles:true,cancelable:true}));
  key(f.d.body,'f');assert.equal(f.d.getElementById('flagBtn').getAttribute('aria-pressed'),'true');key(f.d.body,'ArrowRight');assert(f.d.getElementById('gin'));
  const input=f.d.getElementById('gin');input.focus();assert(f.d.body.classList.contains('answer-keyboard'));key(input,'f');key(input,'ArrowLeft');assert.equal(f.eval('ST.idx'),1);assert.equal(f.eval('ST.flags.size'),1);
  f.w.ExamExperience.review();assert.equal(f.d.getElementById('examReviewCounts').textContent,'1 answered · 1 unanswered · 1 flagged');key(f.d.body,'ArrowLeft');assert.equal(f.eval('ST.idx'),1);
  f.d.querySelector('[data-review-flag]').click();assert.equal(f.eval('ST.idx'),0);assert(f.d.querySelector('.pal.answered.flagged.current'));await f.eval('flushAnswers()');await f.w.ExamExperience.flush();
 }finally{f.dom.window.close();}
});
test('timer expiry bypasses review and duplicate submit requests use one in-flight submission',async()=>{
 const f=fixture();try{
  await f.start();let release,submissions=0;f.w.submitFixture=()=>{submissions++;return new Promise(r=>{release=r;});};
  f.eval("fn=submitFixture;ST.run.attempt.deadline_at=new Date(Date.now()-1000).toISOString();ST.skew=0;startClock()");
  await new Promise(r=>setImmediate(r));assert.equal(submissions,1);assert(!f.d.querySelector('#examReviewSheet[open]'));
  await f.eval('submitExam(true)');assert.equal(submissions,1);release({ok:true,json:{review_open:false,attempt:{score:1,total:2},items:[]}});await new Promise(r=>setImmediate(r));
  assert.equal(f.eval('ST.run'),null);assert(!f.d.body.classList.contains('in-exam'));
 }finally{f.dom.window.close();}
});
test('unreleased review does not expose solution markup; released solutions are collapsed',()=>{
 const f=fixture();try{
  f.w.result={review_open:false,items:[{stem:'Q',explanation:'Secret solution',correct:'A'}]};assert(!f.eval('reviewBody(result)').includes('Secret solution'));
  f.w.result.review_open=true;f.d.getElementById('vReview').innerHTML=f.eval('reviewBody(result)');assert.equal(f.d.querySelector('details.worked-solution').open,false);assert.match(f.d.querySelector('details').textContent,/Secret solution/);
 }finally{f.dom.window.close();}
});
test('notebook feedback stays visible after a checked item leaves today’s due list',()=>{
 const f=fixture();try{
  f.w.eval(fs.readFileSync('web/daily-challenge.js','utf8'));
  f.eval("DASH.mistakes={items:[],due_count:0,remaining:1,mastered:0};DASH.notebookFeedback={q1:{correct:false,explanation:'Divide both sides by 2. Next retry: Tue 17 Nov.'}};");
  assert.match(f.eval('mistakesPanel()'),/Divide both sides by 2/);assert.match(f.eval('mistakesPanel()'),/No retries due/);
 }finally{f.dom.window.close();}
});
test('topic import checks detect reported defects and accept canonical aliases',()=>{
 const {audit}=loadModule('web/question-topic-audit.js');assert.equal(audit([{topic:'Systems of equations',stem:'What is the slope of a line perpendicular to slope 3?'}]).length,1);
 assert.equal(audit([{topic:'Systems of equations',stem:'Solve sqrt(x)+4=11'}]).length,1);
 assert.equal(audit([{topic:'Circles'}],{source_bundle_lesson:'Triangles'}).length,1);
 assert.equal(audit([{topic:'Linear functions and slope'}],{source_bundle_lesson:'Lines'},x=>x==='Lines'?'Linear functions and slope':x).length,0);
});
test('shared headers retain account handlers and course selection across the main portal pages',async()=>{
 for(const page of ['index','admin','study-plan','practice-bundles','checkpoint','register']){
  const dom=new JSDOM(fs.readFileSync('web/'+page+'.html','utf8'),{url:'https://portal.invalid',runScripts:'outside-only'}),d=dom.window.document;let clicks=0;
  const observers=[],Native=dom.window.MutationObserver;dom.window.MutationObserver=class extends Native{constructor(fn){super(fn);observers.push(this);}};
  try{
   const out=d.getElementById('outBtn');out?.addEventListener('click',()=>clicks++);
   dom.window.eval(fs.readFileSync('web/portal-ui.js','utf8'));await new Promise(r=>setImmediate(r));
   assert.equal(d.querySelectorAll('.portal-brand').length,1,page);assert.equal(d.querySelectorAll('#portalAccountMenu').length,1,page);assert.match(d.querySelector('.portal-brand').textContent,/Abdelrahman GhoneemMATH PORTAL/);
   if(out){assert.equal(out.closest('nav').getAttribute('aria-label'),'Account');out.click();assert.equal(clicks,1);}
   if(page==='admin')assert.equal(d.getElementById('trackSel').closest('details').id,'portalAccountMenu');
   if(['study-plan','checkpoint','practice-bundles'].includes(page))assert(d.querySelector('header + .portal-breadcrumb'));
  }finally{for(const observer of observers)observer.disconnect();dom.window.close();}
 }
});
test('weekly report excludes test students and locked review and separates missing work from scores',()=>{
 const {summarize,text}=loadModule('web/weekly-report.js'),from='2026-11-07T00:00:00Z',to='2026-11-14T00:00:00Z';
 const report=summarize({from,to,group:{id:'g',name:'Test group'},students:[{user_id:'a',full_name:'Student A'},{user_id:'b',full_name:'Student B'},{user_id:'t',full_name:'Test account',is_test:true}],members:['a','b','t'].map(user_id=>({user_id,group_id:'g'})),attempts:[{id:'open',user_id:'a',exam_id:'e',started_at:'2026-11-10T10:00:00Z',status:'graded',review_unlocks_at:'2026-11-10T11:00:00Z'},{id:'locked',user_id:'a',exam_id:'e',started_at:'2026-11-10T10:00:00Z',status:'graded',review_unlocks_at:'2026-12-10T11:00:00Z'}],exams:[{id:'e',is_published:true,review_policy:'full_review'}],results:[{user_id:'a',exam_id:'e',submitted_at:'2026-11-10T10:30:00Z'}],assignments:[{exam_id:'e',group_id:'g',open_at:from,close_at:'2026-11-12T00:00:00Z'}],daily:[],answers:[{attempt_id:'open',question_id:'q',is_correct:false},{attempt_id:'locked',question_id:'q',is_correct:false}],questions:[{id:'q',topic:'Circles'}]});
 assert.equal(report.students,2);assert.deepEqual(JSON.parse(JSON.stringify(report.inactive)),['Student B']);assert.deepEqual(JSON.parse(JSON.stringify(report.behind)),[{name:'Student B',count:1}]);assert.deepEqual(JSON.parse(JSON.stringify(report.topics)),[['Circles',1]]);assert.match(text(report,from,to),/Missing work is not a zero score/);
});
test('offline worker caches only public shell assets and leaves exam/API data uncached',async()=>{
 const handlers={},cached=[],matched=[],self={location:{origin:'https://portal.invalid'},addEventListener:(k,v)=>handlers[k]=v};
 const caches={open:async()=>({addAll:async files=>cached.push(...files)}),match:async key=>{matched.push(key);return new Response('Public offline shell');}};
 vm.runInNewContext(fs.readFileSync('web/portal-sw.js','utf8'),{self,caches,URL,Response,fetch:async()=>{throw Error('offline');}});let result;
 handlers.install({waitUntil:p=>result=p});await result;assert.deepEqual(cached,['/offline.html','/portal-ui.css?v=20261114-ui','/icons/portal-192.png','/icons/portal-512.png']);
 for(const request of [{method:'POST',mode:'cors',url:'https://portal.invalid/api/submit'},{method:'GET',mode:'cors',url:'https://portal.invalid/api/answers'},{method:'GET',mode:'cors',url:'https://database.invalid/rest/v1/attempts'}])handlers.fetch({request,respondWith:()=>assert.fail('Assessment API intercepted')});
 handlers.fetch({request:{method:'GET',mode:'navigate',url:'https://portal.invalid/?exam=123'},respondWith:p=>result=p});assert.equal(await (await result).text(),'Public offline shell');assert.deepEqual(matched,['/offline.html']);
});
