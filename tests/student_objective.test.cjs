const {test}=require('node:test');const assert=require('node:assert/strict');const fs=require('node:fs'),vm=require('node:vm');
const html=fs.readFileSync('web/index.html','utf8');const code=html.slice(html.indexOf('let objectiveRequest'),html.indexOf('function show(id)'));
function fixture(data){const dom=new JSDOM('<div id="chooserObjective"></div><div id="dashboardObjective"></div><div id="dashboardContent"></div>',{runScripts:'outside-only'}),c=dom.getInternalVMContext();const elements=Object.fromEntries(['chooserObjective','dashboardObjective','dashboardContent'].map(id=>[id,dom.window.document.getElementById(id)]));const q={select(){return this},eq(){return this},in:async()=>({data})};Object.assign(c,{$:id=>elements[id],ST:{tracks:[{id:'sat'},{id:'est'}],track:{id:'est'}},sb:{from:()=>q},displayWeeklyObjective(){},setInterval(){}});vm.runInContext(code,c);return {c,elements,dom};}
test('SAT and EST Today views retain planner access even without an assigned day',async()=>{for(const data of [null,[],[{title:'Algebra',track_id:'est',time_budget:'60 min'}]]){const f=fixture(data);for(const view of ['vTracks','vList']){await f.c.displayStudyObjective(view);const el=f.elements[view==='vTracks'?'chooserObjective':'dashboardObjective'];assert.equal(el.hidden,false);assert.match(el.innerHTML,/study-plan.html/);}f.dom.window.close();}});
test('objectives are hidden during an exam',async()=>{const f=fixture([]);await f.c.displayStudyObjective('vRun');assert.equal(f.elements.dashboardObjective.hidden,true);f.dom.window.close();});
const {JSDOM}=require('./english-runtime/node_modules/jsdom');
async function linkedExam(exam,extra=[]){
 const dom=new JSDOM('<div id="dashboardContent"></div>',{runScripts:'outside-only',url:'https://portal.test/?study_track=sat&study_exam=linked'}),c=dom.getInternalVMContext();
 Object.assign(c,{ST:{tracks:[{id:'sat'}]},URLSearchParams,DASH:{exams:exam?[exam,...extra]:[]},openTrack:async()=>{},$:id=>dom.window.document.getElementById(id),esc:s=>String(s??''),paintDashboard(){dom.window.document.getElementById('dashboardContent').innerHTML=c.assignedTaskPanel();},wireDashboard(){},startExam(){throw Error('Must not auto-start');}});
 vm.runInContext(html.slice(html.indexOf('function displayTitle('),html.indexOf('function dashboardOverview(')),c);
 vm.runInContext(html.slice(html.indexOf('function assessmentRow('),html.indexOf('function assessmentSection(')),c);
 vm.runInContext(html.slice(html.indexOf('function moduleState('),html.indexOf('function fullExamSection(')),c);
 vm.runInContext(code,c);await c.openStudyLink();return dom;
}
test('study links reuse start, resume, review, closed and retake controls',async()=>{
 for(const [patch,label,disabled] of [[{},'Start',false],[{open:false},'Start',true],[{last:{id:'attempt',status:'in_progress'}},'Resume',false],[{last:{id:'attempt',status:'graded',score:2,total:3}},'Review',false]]){
  const dom=await linkedExam({id:'linked',title:'Quiz',assessment_type:'quiz',questions:3,duration_seconds:600,open:true,...patch});
  const button=dom.window.document.querySelector('button');assert.equal(button.textContent,label);assert.equal(button.disabled,disabled);if(label==='Review')assert.equal(button.dataset.review,'attempt');dom.window.close();
 }
 const dom=await linkedExam({id:'linked',title:'Quiz',assessment_type:'quiz',questions:3,duration_seconds:600,open:true,retake_available:true,last:{id:'a',status:'graded'}});assert.match(dom.window.document.body.textContent,/Start retake/);dom.window.close();
});
test('study links keep content holds and SAT module prerequisites',async()=>{
 for(const patch of [{content_ready:false},{exam_set_code:'set',module_number:2}]){
 const dom=await linkedExam({id:'linked',title:'Quiz',questions:3,duration_seconds:600,open:true,...patch},[{id:'first',exam_set_code:'set',module_number:1}]);assert.equal(dom.window.document.querySelector('button').disabled,true);dom.window.close();}
});
test('unassigned study links never offer a start action',async()=>{const dom=await linkedExam(null);assert.equal(dom.window.document.querySelector('button'),null);assert.match(dom.window.document.body.textContent,/not currently available/);dom.window.close();});
test('progress keys isolate students, tracks and activity; missing evidence stays unavailable',()=>{let js=fs.readFileSync('web/study-plan.js','utf8');const a=js.slice(js.indexOf('function evidence('),js.indexOf('function relevant('));const ctx=vm.createContext({progressCacheSource:null,progressCache:new Map(),progress:[{user_id:'a',track_id:'sat',study_date:'2026-11-05',activity:'lesson',status:'in_progress'}]});vm.runInContext(a,ctx);assert.equal(ctx.state({user_id:'a',track_id:'sat',study_date:'2026-11-05'},'lesson'),'in_progress');assert.equal(ctx.state({user_id:'b',track_id:'sat',study_date:'2026-11-05'},'lesson'),'unavailable');assert.equal(ctx.state({user_id:'a',track_id:'est',study_date:'2026-11-05'},'lesson'),'unavailable');assert.equal(ctx.state({user_id:'a',track_id:'sat',study_date:'2026-11-05'},'practice'),'unavailable');});

test('completed Alex objective remains visible after cutoff and opens its recorded result',async()=>{
 const {JSDOM}=require('./english-runtime/node_modules/jsdom');
 const dom=new JSDOM('<section id="chooserWeeklyObjective"></section><section id="dashboardWeeklyObjective"></section><div id="vList"></div>',{runScripts:'outside-only'});
 const c=dom.getInternalVMContext();Object.assign(c,{ST:{tracks:[{id:'est'}],track:{id:'est'}},objectiveRequest:1,$:id=>dom.window.document.getElementById(id),esc:x=>String(x),sb:{rpc:async()=>({data:{id:'exam',title:'Alex Algebra',open_at:new Date(Date.now()-3600000).toISOString(),close_at:new Date(Date.now()-60000).toISOString(),completed:true,attempt_id:'recorded-attempt',resume:false}})},openReview:async id=>c.reviewed=id,startExam:async()=>{throw Error('must not start another attempt')}});
 vm.runInContext(html.slice(html.indexOf('let weeklyRefresh;'),html.indexOf('let objectiveRequest =')),c);
 await c.displayWeeklyObjective('vList',1);
 const card=c.$('dashboardWeeklyObjective');assert.equal(card.hidden,false);assert.match(card.textContent,/Completed automatically/);
 const button=card.querySelector('button');assert.equal(button.textContent,'View quiz result');await button.onclick();assert.equal(c.reviewed,'recorded-attempt');dom.window.close();
});
test('weekly assessment uses its Cairo date instead of labeling tomorrow as Today',async()=>{
 for(const [offset,label] of [[86400000,'Upcoming'],[0,'Today']]){
  const dom=new JSDOM('<section id="chooserWeeklyObjective"></section><section id="dashboardWeeklyObjective"></section>',{runScripts:'outside-only'}),c=dom.getInternalVMContext();
  const now=Date.parse('2026-11-09T08:00:00Z'),opens=now+offset+3600000;
  c.Date.now=()=>now;Object.assign(c,{ST:{tracks:[{id:'est'}]},objectiveRequest:1,$:id=>dom.window.document.getElementById(id),esc:String,setTimeout(){},clearTimeout(){},sb:{rpc:async()=>({data:{title:'Weekly algebra',open_at:new Date(opens).toISOString(),close_at:new Date(opens+1200000).toISOString()}})}});
  vm.runInContext(html.slice(html.indexOf('let weeklyRefresh;'),html.indexOf('let objectiveRequest =')),c);await c.displayWeeklyObjective('vTracks',1);
  assert.equal(c.$('chooserWeeklyObjective').querySelector('small').textContent,label+' · Alex EST I');assert(c.$('chooserWeeklyObjective').querySelector('button').disabled);dom.window.close();
 }
});

test('Today opens the exact assigned daily assessment and labels the destination',async()=>{
 const dom=new JSDOM('<div id="chooserObjective"></div><div id="dashboardObjective"></div>',{runScripts:'outside-only'}),c=dom.getInternalVMContext();
 const plan={title:'Systems',time_budget:'60 min',track_id:'sat',practice_exam_id:'exact-daily-exam',practice_source:'exam'};
 Object.assign(c,{$:id=>dom.window.document.getElementById(id),ST:{tracks:[{id:'sat'}],track:{id:'sat'}},sb:{from:()=>({select(){return this},eq(){return this},in:async()=>({data:[plan]})})},displayWeeklyObjective(){}});
 vm.runInContext(code,c);await c.displayStudyObjective('vList');
 const a=dom.window.document.querySelector('.btn-primary');
 assert.match(a.getAttribute('aria-label'),/Open assigned daily task/);
 assert.equal(new URL(a.getAttribute('href'),'https://portal.test').searchParams.get('study_exam'),'exact-daily-exam');
 dom.window.close();
 const destination=await linkedExam({id:'linked',title:'Systems assigned quiz',questions:18,duration_seconds:600,open:true});
 assert.match(destination.window.document.querySelector('.assigned-daily-panel').textContent,/ASSIGNED DAILY TASK/);
 destination.window.close();
});

async function todaySummary({track='sat',plans,completion=[],failed=false}={}) {
 const dom=new JSDOM('<div id="chooserObjective"></div><div id="dashboardObjective"></div>',{runScripts:'outside-only'}),c=dom.getInternalVMContext();
 const date=new Intl.DateTimeFormat('en-CA',{timeZone:'Africa/Cairo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
 plans=plans||[{user_id:'one',study_date:date,title:'Systems',instructions:'Group: Sat nov and dec\nSolve.',track_id:track,time_budget:'40 minutes',calculator_allowed:true,practice_exam_id:'exact',skipped_activities:['lesson','retest']}];
 Object.assign(c,{$:id=>dom.window.document.getElementById(id),ST:{tracks:[{id:track}],track:{id:track}},sb:{from:table=>({select(){return this},eq(){return this},in:async()=>table==='student_daily_objectives'?{data:plans}:{data:completion,error:failed?{message:'failed'}:null}})},displayWeeklyObjective(){}});
 vm.runInContext(code,c);await c.displayStudyObjective('vList');return {dom,date,c};
}
test('Today separates December plan from the historical archive and shows recorded group, Cairo date and calculator',async()=>{
 const {dom,date}=await todaySummary();const body=dom.window.document.body;
 assert.match(body.textContent,/Group: Sat nov and dec/);assert.ok(body.textContent.includes(new Intl.DateTimeFormat('en-GB',{weekday:'short',day:'numeric',month:'short',timeZone:'Africa/Cairo'}).format(new Date(date+'T12:00:00Z'))));assert.match(body.textContent,/Calculator allowed/);
 assert(body.querySelector('a[href="/study-plan.html?track=sat"]'));
 assert(body.querySelector('details a[href="/sat-revision.html"]'));
 assert.match(body.textContent,/Progress unavailable/);dom.window.close();
});
test('Today shows only same-student course date and activity evidence, and keeps failures unverified',async()=>{
 const {dom,date,c}=await todaySummary();dom.window.close();
 const rows=[{user_id:'other',track_id:'sat',study_date:date,activity:'practice',status:'completed'},{user_id:'one',track_id:'est',study_date:date,activity:'practice',status:'completed'},{user_id:'one',track_id:'sat',study_date:'2000-01-01',activity:'practice',status:'completed'},{user_id:'one',track_id:'sat',study_date:date,activity:'practice',status:'pending'}];
 const a=await todaySummary({completion:rows});assert.match(a.dom.window.document.body.textContent,/Practice: Awaiting submission/);assert.doesNotMatch(a.dom.window.document.body.textContent,/Completed automatically/);a.dom.window.close();
 const b=await todaySummary({failed:true,completion:[{...rows[3],status:'completed'}]});assert.match(b.dom.window.document.body.textContent,/Practice: Progress unavailable/);b.dom.window.close();
 const d=await todaySummary({completion:[{...rows[3],status:'completed',submitted_at:date+'T08:00:00Z'}]});assert.match(d.dom.window.document.body.textContent,/Practice: Completed automatically · Submitted/);d.dom.window.close();
});
test('EST-only students do not see a SAT pathway and unassigned dates are explicit',async()=>{
 const {dom}=await todaySummary({track:'est',plans:[]});assert.equal(dom.window.document.querySelector('a[href="/study-plan.html?track=sat"]'),null);assert.match(dom.window.document.body.textContent,/No tasks assigned today/);dom.window.close();
});

test('Today refreshes after a return and leaves an active examination untouched',async()=>{
 const dom=new JSDOM('<div id="vTracks"></div><div id="vList" class="hidden"></div>',{runScripts:'outside-only',pretendToBeVisual:true}),c=dom.getInternalVMContext();
 Object.assign(c,{$:id=>dom.window.document.getElementById(id),ST:{run:null},refreshes:[],displayStudyObjective:view=>c.refreshes.push(view)});
 const source=html.slice(html.indexOf('function refreshTodayObjective()'),html.indexOf('// Deep links select'));
 vm.runInContext(source,c);dom.window.document.dispatchEvent(new dom.window.Event('visibilitychange'));
 assert.deepEqual(c.refreshes,['vTracks']);c.ST.run={id:'running'};
 const event=new dom.window.Event('pageshow');Object.defineProperty(event,'persisted',{value:true});dom.window.dispatchEvent(event);
 assert.deepEqual(c.refreshes,['vTracks']);dom.window.close();
});


test('multi-course empty Today is one compact message with every course link inside collapsed details',async()=>{
 const f=fixture([]);f.c.ST.tracks=[{id:'sat'},{id:'est'},{id:'est2'},{id:'act2'}];await f.c.displayStudyObjective('vTracks');
 const card=f.elements.chooserObjective,detail=card.querySelector('details');assert.equal(detail.open,false);assert.equal(card.querySelectorAll('.today-status').length,1);assert.equal(card.querySelectorAll('.today-tasks article').length,0);assert.equal(card.querySelectorAll('.today-actions>a').length,1);assert.equal(card.querySelectorAll('.today-courses .today-course').length,4);assert.equal(card.querySelectorAll('a:not(.today-link)').length,0);assert.doesNotMatch(card.textContent,/no objective assigned for this date|Existing practice and exams remain available/);for(const id of ['sat','est','est2','act2'])assert(detail.querySelector('a[href="/study-plan.html?track='+id+'"]'));f.dom.window.close();
});

test('empty data and objective-read failure are never presented as the same status',async()=>{
 const f=fixture([]);f.c.sb.from=table=>({select(){return this},eq(){return this},in:async()=>table==='student_daily_objectives'?{error:{message:'network'}}:{data:[]}});await f.c.displayStudyObjective('vList');assert.match(f.elements.dashboardObjective.querySelector('.today-status').textContent,/could not be loaded/);assert.doesNotMatch(f.elements.dashboardObjective.textContent,/No tasks assigned/);assert(f.elements.dashboardObjective.querySelector('.today-actions a'));f.dom.window.close();
});
