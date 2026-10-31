const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {JSDOM}=require('./english-runtime/node_modules/jsdom');
const read=f=>fs.readFileSync(f,'utf8');
function setup(track='est',type='lesson_exam'){
 const dom=new JSDOM('<main id="examList"></main>',{runScripts:'outside-only'}),c=dom.getInternalVMContext(),starts=[],reviews=[];
 const timers=new Map();let timerId=0;
 c.setTimeout=fn=>{timers.set(++timerId,fn);return timerId;};c.clearTimeout=id=>timers.delete(id);
 c.flushSearch=()=>{for(const [id,fn]of [...timers]){timers.delete(id);fn();}};
 Object.assign(c,{ST:{track:{id:track,name:track}},DASH:{view:type,access:{practice_open:true},exams:[]},ASSESSMENTS:{full_exam:'Full exams'},esc:s=>String(s??'').replace(/[&<>"']/g,s=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[s])),math(){},$:id=>c.document.getElementById(id),startExam:async(id,untimed)=>starts.push({id,untimed}),openReview:id=>reviews.push(id)});
 const html=read('web/index.html');vm.runInContext(html.slice(html.indexOf('function assessmentRow('),html.indexOf('function moduleState(')),c);
 c.wireDashboard=()=>{c.document.querySelectorAll('[data-start]').forEach(b=>b.onclick=()=>c.startExam(b.dataset.start,c.document.querySelector(`[data-timer="${b.dataset.start}"]`)?.value==='untimed'));c.document.querySelectorAll('[data-review]').forEach(b=>b.onclick=()=>c.openReview(b.dataset.review));};
 c.paintDashboardContent=()=>{c.document.getElementById('dashboardContent').innerHTML=c.assessmentSection(c.DASH.view);c.wireDashboard();};
 c.paintDashboard=()=>{c.document.getElementById('examList').innerHTML='<nav class="student-tabs">'+(c.DASH.access.practice_open?'<button data-view="lesson_exam" hidden>Lesson exams</button>':'')+'</nav><div id="dashboardContent"></div>';c.paintDashboardContent();};
 c.setDashboardView=view=>{c.DASH.view=view;c.paintDashboard();};c.dashboardOverview=()=>'<p>Saved progress</p>';
 for(const f of ['lesson-taxonomy.js','lesson-exam-catalog.js','assessment-index.js','lesson-exams.js'])vm.runInContext(read('web/'+f),c);
 const rows=c.GhoneemAssessmentIndex.filter(x=>x.track_id===track).map(x=>({...x,...c.GhoneemLessonCatalog.find(a=>a.id===x.id),title:c.GhoneemLessonCatalog.find(a=>a.id===x.id)?.title||x.lesson+' — '+x.id,questions:25,duration_seconds:2400,open:true}));c.DASH.exams=rows;
 return {c,dom,rows,starts,reviews};
}
function change(c,id,value){const el=c.document.getElementById(id);el.value=value;el[id==='lessonExamSearch'?'oninput':'onchange']();c.flushSearch();}
function visibleSets(group){return [...group.querySelectorAll('.exam-row')].filter(row=>!row.closest('.lesson-older-sets,.lesson-duplicate-sets'));}
test('all five tracks combine previous and recent lesson exams and quizzes into collapsed topic groups',async()=>{
 for(const track of ['sat','est','est2','est_eng','act2'])for(const type of ['lesson_exam','quiz']){
  const {c,dom,rows,starts}=setup(track,type);c.paintDashboard();const doc=c.document,expected=rows.filter(e=>e.assessment_type===type);
  assert.equal(doc.querySelector('[data-view="lesson_exam"]').hidden,false);
  assert.equal(doc.querySelectorAll('.lesson-exam-group').length,new Set(expected.map(x=>x.lesson)).size);
  assert.equal(doc.querySelectorAll('.lesson-exam-group[open]').length,0);
  for(const group of doc.querySelectorAll('.lesson-exam-group')){assert.equal(visibleSets(group).length,1);assert(group.querySelectorAll('.lesson-older-sets>.lesson-set').length<=5);}
  const first=doc.querySelector('[data-start]');assert(first);await first.click();assert.equal(starts[0].untimed,type==='lesson_exam');
  if(type==='lesson_exam'){doc.querySelector(`[data-timer="${first.dataset.start}"]`).value='timed';await first.click();assert.equal(starts[1].untimed,false);}
  assert.doesNotMatch(c.dashboardOverview(),/new lesson exams/);assert.equal(doc.querySelector('.lesson-new-badge'),null);
  dom.window.close();
 }
});
test('search keeps focus and searches older sets and component topics of mixed quizzes',()=>{
 const {c,dom}=setup('sat','quiz');c.paintDashboard();const mixed=c.GhoneemAssessmentIndex.find(e=>e.track_id==='sat'&&e.assessment_type==='quiz'&&e.topics.length>2);
 const search=c.document.getElementById('lessonExamSearch');search.focus();change(c,'lessonExamSearch',mixed.id);assert.equal(c.document.activeElement,search);assert(c.document.querySelector(`[data-start="${mixed.id}"]`));
 change(c,'lessonExamSearch',mixed.topics[0]);assert(c.document.getElementById('lessonExamResults').textContent.includes('Mixed-topic quizzes'));
 change(c,'lessonExamSearch','unmatched words');assert.match(c.document.getElementById('lessonExamResults').textContent,/No quizzes/);c.document.getElementById('lessonExamReset').click();assert.equal(c.document.getElementById('lessonExamScope').value,'all');dom.window.close();
});
test('pagination retains every assignment, including duplicate copies, without a long flat list',()=>{
 const {c,dom,rows}=setup();c.paintDashboard();const target='Mixed lesson practice';change(c,'lessonExamLesson',target);
 const expected=rows.filter(e=>e.assessment_type==='lesson_exam'&&e.lesson===target).map(e=>e.id).sort(),found=new Set();
 const more=c.document.querySelector('.lesson-older-sets');assert(more);more.open=true;
 let pages=0;
 do{
  for(const b of c.document.querySelectorAll('[data-start]'))found.add(b.dataset.start);
  const next=[...c.document.querySelectorAll('[data-lesson-page]')].find(b=>b.textContent==='Next'&&!b.disabled);if(!next)break;
  next.click();assert(c.document.querySelector('.lesson-older-sets').open);assert(c.document.querySelector('.lesson-exam-group').open);assert(++pages<100);
 }while(true);
 assert(pages>1);assert.deepEqual([...found].sort(),Array.from(expected));dom.window.close();
});
test('in-progress work wins over newer sets and review, retake, readiness and timer gates are preserved',async()=>{
 const {c,dom,starts,reviews}=setup();const base=c.DASH.exams.find(e=>e.assessment_type==='lesson_exam');
 const progress={...base,id:'old-progress',created_at:'2020-01-01',last:{id:'live-attempt',status:'in_progress',untimed:true}},recent={...base,id:'newest',created_at:'2030-01-01'},completed={...base,id:'done',last:{id:'saved',status:'submitted',score:10,total:25}},held={...base,id:'held',content_ready:false},closed={...base,id:'closed',open:false};
 c.DASH.exams=[recent,completed,held,closed,progress];c.paintDashboard();const group=c.document.querySelector('.lesson-exam-group');assert(group.open);assert.equal(visibleSets(group)[0].querySelector('[data-start]').dataset.start,'old-progress');assert.equal(c.document.querySelector('[data-start="old-progress"]').textContent,'Resume');assert.equal(c.document.querySelector('[data-timer="old-progress"]'),null);
 assert(c.document.querySelector('[data-start="held"]').disabled);assert(c.document.querySelector('[data-start="closed"]').disabled);
 c.document.querySelector('[data-review="saved"]').click();assert.deepEqual(reviews,['saved']);await c.document.querySelector('[data-start="done"]').click();assert.deepEqual(starts,[{id:'done',untimed:true}]);
 change(c,'lessonExamScope','completed');assert.equal(c.document.querySelectorAll('[data-review]').length,1);change(c,'lessonExamScope','progress');assert.equal(c.document.querySelectorAll('[data-start]').length,1);dom.window.close();
});
test('identical older question sets share a listing while their separate attempts remain accessible',()=>{
 const {c,dom}=setup('sat');const copy=c.GhoneemAssessmentIndex.find(e=>e.track_id==='sat'&&e.same_set_as),ids=[copy.id,copy.same_set_as];
 c.DASH.exams=c.DASH.exams.filter(e=>ids.includes(e.id));c.DASH.exams[1].last={id:'historical',status:'submitted',score:5,total:5};c.paintDashboard();
 assert.equal(c.document.querySelectorAll('.lesson-exam-group').length,1);assert.equal(visibleSets(c.document.querySelector('.lesson-exam-group')).length,1);assert.equal(c.document.querySelectorAll('.lesson-duplicate-sets').length,1);assert(c.document.querySelector('[data-review="historical"]'));assert.match(c.document.querySelector('.lesson-set-count').textContent,/1 set/);assert.equal(c.DASH.exams.length,2);dom.window.close();
});
test('track/type changes reset filters; stale rows and unsafe titles do not leak; withheld navigation stays withheld',()=>{
 const {c,dom}=setup();const foreign=c.GhoneemAssessmentIndex.find(x=>x.track_id==='sat'&&x.assessment_type==='quiz');c.DASH.exams.push({...foreign,open:true});c.paintDashboard();assert.equal(c.document.querySelector(`[data-start="${foreign.id}"]`),null);
 change(c,'lessonExamSearch','unmatched');c.DASH.view='quiz';c.paintDashboard();assert.equal(c.document.getElementById('lessonExamSearch').value,'');
 c.ST.track={id:'sat',name:'SAT'};c.DASH.exams=[{...foreign,title:'<img src=x onerror=alert(1)>',duration_seconds:600,open:true}];c.paintDashboard();assert.equal(c.document.querySelectorAll('.lesson-exam-group').length,1);assert.equal(c.document.querySelector('img'),null);
 c.DASH.access.practice_open=false;c.paintDashboard();assert.equal(c.document.querySelector('[data-view="lesson_exam"]'),null);dom.window.close();
});
test('difficulty and format searches work across releases; full exams still use the original renderer',()=>{
 const {c,dom,rows}=setup('est2');c.paintDashboard();change(c,'lessonExamLesson','Statistics and data analysis');change(c,'lessonExamSearch','set 02');assert.equal(c.document.querySelectorAll('[data-start]').length,1);change(c,'lessonExamDifficulty','Hard');assert.equal(c.document.querySelectorAll('[data-start]').length,0);
 const api=c.LessonExamLibrary;for(const [term,label] of [['graphs','Figures and tables'],['MCQ','Multiple choice'],['word problems','Applications'],['FITB','Numerical response']]){const expected=rows.filter(e=>e.assessment_type==='lesson_exam'&&e.formats?.includes(label)).length;assert.equal(api.groups(rows,'est2',{query:term}).reduce((n,g)=>n+g.exams.length,0),expected);}
 assert.match(c.assessmentSection('full_exam'),/assessmentSort/);assert.doesNotMatch(c.assessmentSection('full_exam'),/lesson-exam-group/);dom.window.close();
});
test('public index covers only display metadata and both served source copies match',()=>{
 const {c,dom}=setup();assert.equal(c.GhoneemAssessmentIndex.length,776);assert.equal(c.GhoneemAssessmentIndex.filter(e=>e.same_set_as).length,2);assert.equal(c.GhoneemLessonCatalog.length,154);
 for(const e of [...c.GhoneemAssessmentIndex,...c.GhoneemLessonCatalog])for(const k of ['question_ids','stem','correct','explanation','question_hash','key_hash','user_id','group_id','attempts'])assert.equal(k in e,false);
 for(const f of ['index.html','admin.html','lesson-exams.js','lesson-exams.css','lesson-exam-catalog.js','assessment-index.js'])assert.equal(read('web/'+f),read(require('./public-artifact-dir.cjs')+'/'+f));
 assert.match(read('web/index.html'),/assessment-index.js\?v=20261030/);assert.match(read('web/admin.html'),/new_lessons/);dom.window.close();
});
test('rapid search input renders only the final value and keeps focus and start actions',()=>{
 const {c,dom,starts}=setup('sat','quiz');c.paintDashboard();const search=c.document.getElementById('lessonExamSearch');search.focus();
 const before=c.document.getElementById('lessonExamResults').innerHTML;let renders=0;c.math=()=>renders++;
 const exam=c.DASH.exams.find(e=>e.assessment_type==='quiz');
 for(const value of ['never-matches','another-query',exam.id]){search.value=value;search.oninput();}
 assert.equal(c.document.getElementById('lessonExamResults').innerHTML,before);assert.equal(renders,0);
 c.flushSearch();assert.equal(renders,1);assert.equal(c.document.activeElement,search);
 c.document.querySelector(`[data-start="${exam.id}"]`).click();assert.equal(starts[0].id,exam.id);
 c.flushSearch();assert.equal(renders,1);dom.window.close();
});
test('pending search cannot repaint after navigating to another course or view',()=>{
 const {c,dom}=setup();c.paintDashboard();const search=c.document.getElementById('lessonExamSearch');search.value='old';search.oninput();
 c.ST.track={id:'sat'};c.DASH.view='quiz';c.paintDashboard();
 const current=c.document.getElementById('dashboardContent').innerHTML;let renders=0;c.math=()=>renders++;
 c.flushSearch();assert.equal(renders,0);assert.equal(c.document.getElementById('dashboardContent').innerHTML,current);
 assert.equal(c.document.getElementById('lessonExamSearch').value,'');dom.window.close();
});
test('clearing, changing a filter, and committing composed text leave no stale search',()=>{
 const {c,dom}=setup();c.paintDashboard();const search=c.document.getElementById('lessonExamSearch');let renders=0;c.math=()=>renders++;
 search.value='unmatched';search.oninput();search.value='';search.oninput();assert.equal(renders,1);c.flushSearch();assert.equal(renders,1);
 search.value='unmatched';search.oninput();const filter=c.document.getElementById('lessonExamScope');filter.value='completed';filter.onchange();assert.equal(renders,2);c.flushSearch();assert.equal(renders,2);
 search.value='composing';search.oninput({isComposing:true});c.flushSearch();assert.equal(renders,2);
 search.oncompositionend();c.flushSearch();assert.equal(renders,3);dom.window.close();
});
test('legacy title lookup matches individual classification and refreshes live availability',()=>{
 const {c,dom}=setup('sat');const rows=['Circles','Linear equations','Mixed review'].map((title,i)=>({id:'legacy-'+i,title,track_id:'sat',assessment_type:'quiz',open:true}));
 const grouped=c.LessonExamLibrary.groups(rows,'sat',{type:'quiz'});
 for(const group of grouped)for(const exam of group.exams)assert.equal(group.lesson,c.LessonExamLibrary.lessonFor(exam,'sat'));
 rows[0].open=false;const ready=c.LessonExamLibrary.groups(rows,'sat',{type:'quiz',scope:'available'}).flatMap(g=>g.exams);
 assert.equal(ready.length,2);assert(!ready.some(e=>e.id===rows[0].id));dom.window.close();
});
