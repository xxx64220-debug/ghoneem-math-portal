const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const {JSDOM}=require('./english-runtime/node_modules/jsdom');
const read=f=>fs.readFileSync('web/'+f,'utf8');
const index=read('index.html');
const navigation=index.slice(index.indexOf('function setDashboardView('),index.indexOf('function dashboardOverview('));
function student(track,{closed=false,hidden=false}={}){
 const dom=new JSDOM('<div id="examList"></div>',{runScripts:'outside-only'}),w=dom.window,queries=[];
 w.ST={track:{id:track,name:track}};w.DASH={view:'overview',searchTerm:'',revisionVisible:!hidden,access:{practice_open:!closed},history:[],exams:[],lessons:[{lesson:track==='est_eng'?'SEC · Pronouns and agreement':'Circles',seen:4,correct:1,percent:25}]};
 w.REV={track,mode:'questions',data:null,lesson:'saved lesson',session:{responses:['B']}};
 w.$=id=>w.document.getElementById(id);w.esc=String;w.ASSESSMENTS={};w.reportButton=()=>'';w.math=()=>{};w.wireDashboard=()=>{};
 for(const name of ['dashboardOverview','dailyPanel','revisionPanel','mistakesPanel','drillPanel','focusSection','historySection','fullExamSection','assessmentSection'])w[name]=()=>'<p>'+name+'</p>';
 w.searchSection=()=>'<p>Search results</p>';w.refreshRevision=async()=>{throw new Error('Reference must not query revision');};
 w.sb={from:table=>{const q={select:()=>q,eq:(key,value)=>{queries.push({table,key,value});return q;},gte:()=>q,lt:async()=>({data:[]})};return q;}};
 const controls=read('portal-controls.js');w.eval(read('lesson-taxonomy.js')+'\n'+read('revision-formulas.js')+'\n'+navigation+'\n'+controls.slice(controls.indexOf('(function(){')));
 w.scrollTo=()=>{};w.eval(read('portal-navigation.js'));w.eval(read('portal-management.js'));
 w.paintDashboard();return {dom,w,queries};
}
for(const track of ['sat','est','est2','est_eng'])test('student reference and diagnosis are separate destinations for '+track,async()=>{
 const f=student(track,{hidden:true});try{const {w}=f,d=w.document;
 assert(d.querySelector('[data-view="formulas"]'));assert(d.querySelector('[data-view="finalsDiagnosis"]'));assert(!d.querySelector('[data-view="revision"]'));
 assert.equal(d.querySelector('[data-view="formulas"]').hidden,false);assert.equal(d.querySelector('[data-view="finalsDiagnosis"]').hidden,false);
 w.setDashboardView('formulas');assert(d.querySelector('.formula-panel'));assert.equal(w.REV.data,null);assert.equal(w.REV.lesson,'saved lesson');assert.equal(w.REV.session.responses[0],'B');
 if(track==='est_eng'){assert.equal(d.querySelectorAll('[data-formula-lesson]').length,17);assert.match(d.querySelector('.formula-panel').textContent,/English rules/);}
 const lesson=d.querySelectorAll('[data-formula-lesson]')[1];lesson.click();assert(d.querySelector('.formula-lesson h3').textContent===lesson.dataset.formulaLesson);
 w.setDashboardView('finalsDiagnosis');await new Promise(r=>setImmediate(r));assert.match(d.querySelector('#dashboardContent').textContent,/Diagnosis/);
 assert.deepEqual(f.queries,[{table:'practice_notebook',key:'questions.track_id',value:track}]);
 d.querySelector('[data-diagnosis-formulas]').click();assert(d.querySelector('.formula-lesson h3').textContent===w.DASH.lessons[0].lesson);
 w.setDashboardView('finalsDiagnosis');const input=d.getElementById('dashboardSearch');input.value='test';input.oninput({target:input});assert.match(d.getElementById('dashboardContent').textContent,/Search results/);assert(!d.querySelector('[data-view="finalsDiagnosis"]').classList.contains('active'));
 }finally{f.dom.window.close();}
});
for(const track of ['sat','est','est2','est_eng'])test('closed practice preserves read-only reference and diagnosis for '+track,async()=>{
 const f=student(track,{closed:true});try{const {w}=f,d=w.document;w.setDashboardView('formulas');assert.equal(w.DASH.view,'formulas');assert(d.querySelector('[data-formulas-to-questions]').disabled);
 w.setDashboardView('finalsDiagnosis');await new Promise(r=>setImmediate(r));assert.equal(w.DASH.view,'finalsDiagnosis');assert(!d.querySelector('[data-diagnosis-formulas]').disabled);
 assert([...d.querySelectorAll('[data-diagnosis-revision], [data-go="drill"]')].every(b=>b.disabled));
 }finally{f.dom.window.close();}
});
test('staff reference script executes before its navigation extension',()=>{
 const dom=new JSDOM(read('admin.html'));
 try{
  const doc=dom.window.document,scripts=[...doc.scripts].map(s=>(s.getAttribute('src')||'').split('?')[0]);
  assert(doc.querySelector('link[href^="/formula-reference.css"]'));
  assert(scripts.indexOf('/lesson-taxonomy.js')<scripts.indexOf('/revision-formulas.js'));
  assert(scripts.indexOf('/revision-formulas.js')<scripts.indexOf('hardest-questions.js'));
  assert(doc.querySelector('[data-v="formulasAdmin"]'));
 }finally{dom.window.close();}
});

test('an unmatched diagnosed topic never silently displays another reference lesson',()=>{
 const f=student('sat');try{const html=f.w.revisionFormulaPanel({track:'sat',selectedLesson:'Unknown topic',standalone:true});assert.match(html,/No exact reference match/);assert.match(html,/<h3>Unknown topic<\/h3>/);}finally{f.dom.window.close();}
});

for(const track of ['sat','est','est2'])test('student bottom skills reject invalid and foreign evidence and count each lesson once for '+track,async()=>{
 const f=student(track);try{
  const rows=[
   {lesson:' Circles ',seen:4,correct:1,percent:25,track_id:track},
   {lesson:'Circles',seen:3,correct:0,percent:0,track_id:track},
   {lesson:'Functions',seen:4,correct:2,percent:50,track_id:track},
   {lesson:'Limited',seen:2,percent:0},
   {lesson:'Foreign',seen:8,percent:0,track_id:track==='sat'?'est':'sat'},
   ...['','Mixed / untagged','Unclassified questions'].map(lesson=>({lesson,seen:4,percent:0})),
   ...[null,'',' ',NaN,Infinity,-1,101].map(percent=>({lesson:'Invalid '+String(percent),seen:4,percent}))
  ];
  f.w.DASH.lessons=rows;f.w.setDashboardView('finalsDiagnosis');await new Promise(r=>setImmediate(r));
  const cards=[...f.w.document.querySelectorAll('.diagnosis-bottom .lesson-card')];
  assert.equal(cards.length,2);assert.match(cards[0].textContent,/Circles.*25%/s);assert.match(cards[1].textContent,/Functions.*50%/s);
  // The hosted checkout is ESM; evaluate the browser/CommonJS wrapper directly.
  const context={module:{exports:{}}};require('node:vm').runInNewContext(read('hardest-questions.js'),context);
  const {weakSkills}=context.module.exports;
  const staff=weakSkills(rows.map(x=>({...x,questions_seen:x.seen})),{track});
  assert.deepEqual(cards.map(x=>x.querySelector('[data-diagnosis-formulas]').dataset.diagnosisFormulas),Array.from(staff,x=>x.lesson));
  assert.equal(rows[0].lesson,' Circles ','source data is preserved');
 }finally{f.dom.window.close();}
});
