const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {JSDOM}=require('./english-runtime/node_modules/jsdom');
function setup(){
 const dom=new JSDOM(fs.readFileSync('web/study-plan.html','utf8'),{runScripts:'outside-only',url:'https://portal.test/study-plan.html?track=sat&date=2026-11-17'}),w=dom.window;
 w.eval=code=>vm.runInContext(code,dom.getInternalVMContext());
 w.supabase={createClient:()=>({})};
 w.eval(fs.readFileSync('web/study-plan.js','utf8').replace(/boot\(\);\s*$/,''));
 const record={user_id:'one',track_id:'sat',study_date:'2026-11-17',title:'Review systems',instructions:'Explain each step.',time_budget:'60 minutes',lesson:'Linear systems',destination:'practice',practice_source:'exam',calculator_allowed:true,lesson_exam_id:'exam1',practice_exam_id:'exam2',retest_exam_id:'exam3',skipped_activities:[]};
 w.fixture={record};
 w.eval(`me={id:'teacher'};staff=true;ready=true;loading=false;initialContextPending=false;$('date').value='2026-11-17';followToday=false;groups=[{id:'g',track_id:'sat',name:'SAT online',plan_version:1,teaching_plan:'Review systems'}];members=[{user_id:'one',group_id:'g'}];students=[{user_id:'one',full_name:'Student One'}];$('group').innerHTML='<option value="">All</option><option value="g">SAT online</option>';$('group').value='g';selectStudents();plans=[fixture.record];progress=['lesson','practice','retest'].map(activity=>({user_id:'one',track_id:'sat',study_date:'2026-11-17',activity,status:'pending'}));scheduleVerified=true;assessmentMetadataVerified=true;enrollmentVerified=true;enrollmentWindows=[{user_id:'one',track_id:'sat',status:'active'}];assignedAssessments=exams=['exam1','exam2','exam3'].map(id=>({id,title:id,is_published:true}));scheduleAssignments=exams.map(e=>({id:'assignment-'+e.id,exam_id:e.id,user_id:'one',open_at:'2026-11-16T08:00:00Z',close_at:'2026-11-18T08:00:00Z',exams:{...e,duration_seconds:1200}}));`);
 let writes=[];
 w.sb=undefined;
 w.eval(`sb.from=table=>{const chain={select:()=>chain,eq:()=>chain,in:()=>chain,order:()=>chain,range:async()=>({data:table==='exams'?exams:plans,error:null}),upsert:data=>({select:async()=>{window.writes.push({table,data});return {data,error:null}}})};return chain};`);
 w.writes=writes;for(const el of w.document.querySelectorAll('dialog')){el.showModal=()=>{el.open=true};el.close=()=>{el.open=false};}
 w.eval(fs.readFileSync('web/planner-workspace.js','utf8'));w.render();
 return {w,writes,close:()=>w.close()};
}
test('Today deduplicates existing assignments, includes multi-day windows and preserves target IDs',()=>{
 const {w,writes,close}=setup();w.eval("staff=false;me.id='one';scheduleAssignments.push({...scheduleAssignments[0],id:'duplicate'});render();");
 assert.equal(w.document.querySelectorAll('.today-assignment').length,3);
 const href=w.document.querySelector('.assessment-link').href;assert.match(href,/study_exam=exam1/);assert.match(href,/study_date=2026-11-17/);assert.equal(writes.length,0);close();
});
test('statuses separate missing links, skips and completed evidence from pending work',()=>{
 const {w,close}=setup();w.eval("progress[0].status='completed';progress[1].status='skipped';progress[2].status='needs_link';render();");
 for(const [cls,value] of [['completed','1'],['skipped','1'],['needs_link','1'],['pending','0']])assert.equal(w.document.querySelector('#statusOverview .'+cls+' strong').textContent,value);close();
});
test('draft save persists partial instructions without any database write and isolates accounts',async()=>{
 const {w,writes,close}=setup();await w.edit();const f=w.document.getElementById('planForm');f.elements.title.value='Not ready';f.elements.instructions.value='';w.PlannerWorkspace.saveDraft('day');
 const saved=JSON.parse(w.localStorage.getItem('ghoneem.planner.drafts.v1.teacher'));assert.equal(saved.length,1);assert.equal(saved[0].values.title,'Not ready');assert.equal(writes.length,0);
 w.eval("me.id='another-teacher';render();");w.document.getElementById('draftsButton').click();assert.match(w.document.getElementById('draftList').textContent,/No drafts yet/);close();
});
test('resuming a draft restores exact scope and fields with no publication',async()=>{
 const {w,writes,close}=setup();await w.edit();w.document.getElementById('planForm').elements.title.value='Retest linear systems';w.PlannerWorkspace.saveDraft('day');const d=JSON.parse(w.localStorage.getItem('ghoneem.planner.drafts.v1.teacher'))[0];w.eval('load=async()=>true;');await w.PlannerWorkspace.resumeDraft(d.id);assert.equal(w.document.getElementById('planForm').elements.title.value,'Retest linear systems');assert.equal(writes.length,0);close();
});
test('a changed roster cannot expand a saved draft to additional students',async()=>{
 const {w,writes,close}=setup();w.eval("students.push({user_id:'two',full_name:'Two'});members.push({group_id:'g',user_id:'two'});selectStudents();");await w.edit();w.PlannerWorkspace.saveDraft('day');const d=JSON.parse(w.localStorage.getItem('ghoneem.planner.drafts.v1.teacher'))[0];w.eval("students.push({user_id:'three',full_name:'Three'});members.push({group_id:'g',user_id:'three'});load=async()=>true;");await w.PlannerWorkspace.resumeDraft(d.id);assert.match(w.document.getElementById('draftError').textContent,/roster changed/);assert.equal(writes.length,0);close();
});
test('stale objectives block draft resume and publishing without overwriting',async()=>{
 const {w,writes,close}=setup();await w.edit();w.PlannerWorkspace.saveDraft('day');const d=JSON.parse(w.localStorage.getItem('ghoneem.planner.drafts.v1.teacher'))[0];w.eval("plans[0].title='New published work';load=async()=>true;");await w.PlannerWorkspace.resumeDraft(d.id);assert.match(w.document.getElementById('draftError').textContent,/Published objectives changed/);
 const f=w.document.getElementById('planForm');f.elements.review_flags.checked=true;await f.onsubmit({preventDefault(){},target:f});assert.match(w.document.getElementById('saveError').textContent,/Published objectives changed/);assert.equal(writes.length,0);close();
});
test('publishing is explicit, preserves assessment IDs and removes only the published draft',async()=>{
 const {w,writes,close}=setup();await w.edit();w.PlannerWorkspace.saveDraft('day');w.eval('load=async()=>true;');const f=w.document.getElementById('planForm');f.elements.review_flags.checked=true;await f.onsubmit({preventDefault(){},target:f});assert.equal(writes.length,1);assert.equal(writes[0].table,'student_daily_objectives');assert.equal(writes[0].data[0].practice_exam_id,'exam2');assert.equal(JSON.parse(w.localStorage.getItem('ghoneem.planner.drafts.v1.teacher')).length,0);close();
});
test('unreviewed flags keep a plan in draft mode',async()=>{
 const {w,writes,close}=setup();await w.edit();const f=w.document.getElementById('planForm');f.elements.lesson_exam_id.value='';await f.onsubmit({preventDefault(){},target:f});assert.match(w.document.getElementById('saveError').textContent,/review the flags/);assert.equal(writes.length,0);close();
});
test('student role cannot save drafts or publish, even by invoking handlers',async()=>{
 const {w,writes,close}=setup();await w.edit();w.eval("staff=false;render();");w.PlannerWorkspace.saveDraft('day');const f=w.document.getElementById('planForm');await f.onsubmit({preventDefault(){},target:f});assert.equal(w.localStorage.length,0);assert.equal(writes.length,0);assert(w.document.getElementById('draftsButton').hidden);close();
});
test('group roadmap draft remains unpublished and rejects changed version',async()=>{
 const {w,writes,close}=setup();await w.editRoadmap('g');w.document.getElementById('roadmapForm').elements.teaching_plan.value='New weekly topics';w.PlannerWorkspace.saveDraft('roadmap');const d=JSON.parse(w.localStorage.getItem('ghoneem.planner.drafts.v1.teacher'))[0];w.eval('groups[0].plan_version=2;load=async()=>true;');await w.PlannerWorkspace.resumeDraft(d.id);assert.match(w.document.getElementById('draftError').textContent,/roadmap changed/);assert.equal(writes.length,0);close();
});
test('Alex Tuesday item is linked to existing assignment and prioritized without creating one',()=>{
 const {w,writes,close}=setup();w.eval("$('track').value='est';groups=[{id:alexSchedule.group,name:'Alex',track_id:'est'}];$('group').innerHTML='<option value=\"\">All</option>';members=[{user_id:'one',group_id:alexSchedule.group}];scheduleAssignments.push({id:'weekly',exam_id:'existing-alex',group_id:alexSchedule.group,open_at:'2026-11-17T11:10:00Z',close_at:'2026-11-17T11:30:00Z',exams:{title:'Alex — Tuesday Algebra',duration_seconds:1200}});render();");assert.match(w.document.querySelector('.today-assignment').textContent,/ALEX TUESDAY/);assert.equal(writes.length,0);close();
});
test('overlapping narrow windows across Cairo midnight are possible conflicts, not proven lesson clashes',()=>{
 const {w,writes,close}=setup();w.eval("scheduleAssignments.forEach(a=>{a.open_at='2026-11-16T21:45:00Z';a.close_at='2026-11-16T22:30:00Z'});render();");assert.match(w.document.getElementById('planChecks').textContent,/Possible schedule conflict/);assert.match(w.document.getElementById('planChecks').textContent,/Lesson times, other courses and external calendars are not verified/);assert.equal(writes.length,0);close();
});

test('broad assignment availability is not presented as a timetable conflict',()=>{const {w,close}=setup();assert.doesNotMatch(w.document.getElementById('planChecks').textContent,/Possible schedule conflict/);close();});

test('Today keeps old open-ended assignments out of the featured list and bounds large agendas',()=>{
 const {w,close}=setup();w.eval("for(let i=0;i<100;i++)scheduleAssignments.push({id:'older-'+i,exam_id:'older-'+i,user_id:'one',open_at:null,close_at:null,exams:{title:'Older assignment '+i}});render();");
 assert.equal(w.document.querySelectorAll('.today-assignment').length,3);assert.doesNotMatch(w.document.getElementById('todayAssignments').textContent,/Older assignment/);assert.match(w.document.getElementById('todayAssignments').textContent,/Browse all 103 assignments/);
 w.eval("for(let i=0;i<20;i++)scheduleAssignments.push({id:'today-'+i,exam_id:'today-'+i,user_id:'one',open_at:'2026-11-17T10:00:00Z',close_at:null,exams:{title:'Opens today '+i}});render();");
 assert.equal(w.document.querySelectorAll('.today-assignment').length,6);assert.match(w.document.getElementById('todayAssignments').textContent,/Showing the first 6/);w.eval('scheduleVerified=false;scheduleAssignments=[];render();');assert.match(w.document.getElementById('todayAssignments').textContent,/Browse existing assignments/);assert.doesNotMatch(w.document.getElementById('todayAssignments').textContent,/Browse all 0/);close();
});
