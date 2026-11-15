const vm=require('node:vm');
// December EST pathways use course-scoped destinations and personal target evidence.
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('fs');const {JSDOM}=require('./english-runtime/node_modules/jsdom');
function setup(error=null,beforeBoot=null){const dom=new JSDOM(fs.readFileSync('web/study-plan.html','utf8'),{runScripts:'outside-only',url:'https://portal.test/study-plan.html'});const w=dom.window;w.eval=code=>vm.runInContext(code,dom.getInternalVMContext());let writes=[];w.supabase={createClient:()=>({from:table=>({upsert:row=>({select:async()=>{writes.push({table,row});return {data:[row],error}}})})})};beforeBoot?.(w);w.eval(fs.readFileSync('web/study-plan.js','utf8').replace(/boot\(\);\s*$/,'')+`me={id:'one'};staff=false;$('date').value='2026-11-05';plans=[{user_id:'one',track_id:'sat',study_date:'2026-11-05',title:'<img src=x onerror=alert(1)>',instructions:'Review systems',lesson:'Systems',time_budget:'60 min',calculator_allowed:true,destination:'practice',practice_exam_id:'exam-one'}];progress=['lesson','practice','retest'].map(activity=>({user_id:'one',track_id:'sat',study_date:'2026-11-05',activity,status:activity==='practice'?'pending':'needs_link'}));render();`);return {w,writes};}
test('wrapped browser history keeps its receiver and preserves host state while planner tabs change',()=>{
 const {w}=setup(null,w=>w.eval("window.history.replaceState=(function(original){return function(...args){return original.apply(history,args)}})(window.history.replaceState);"));
 try{
  w.history.replaceState({host:'keep'},'','/study-plan.html?track=sat');
  w.eval("initialContextPending=false;render();");
  assert.equal(new URL(w.location.href).searchParams.get('view'),'today');
  assert.equal(w.history.state.host,'keep');
  w.eval("progressView=true;render();");
  assert.equal(new URL(w.location.href).searchParams.get('view'),'progress');
  assert.equal(w.document.getElementById('progressTab').getAttribute('aria-pressed'),'true');
  w.document.getElementById('dayTab').click();
  assert.equal(w.document.getElementById('progressTab').getAttribute('aria-pressed'),'false');
  assert.equal(w.document.querySelectorAll('.card').length,3);
 }finally{w.close();}
});
test('a blocked History update cannot blank the study plan or rewrite assessment data',()=>{
 const {w,writes}=setup();let failures=0;w.console.warn=()=>{};
 try{
  w.history.replaceState=()=>{failures++;throw new w.TypeError('replaceState called on an object that does not implement interface History');};
  w.eval("initialContextPending=false;render();");
  assert.equal(failures,1);assert.equal(w.document.querySelectorAll('.card').length,3);
  assert.match(w.document.querySelectorAll('.card')[1].querySelector('a').href,/study_exam=exam-one/);
  assert.equal(writes.length,0);
 }finally{w.close();}
});
test('day shows read-only progress and preserves safe assessment links',()=>{
 const {w,writes}=setup();
 assert.equal(w.document.querySelectorAll('.card').length,3);
 assert.equal(w.document.querySelectorAll('#content select, [data-activity], [data-plan]').length,0);
 assert.equal(w.document.querySelectorAll('#content img').length,0);
 assert.match(w.document.querySelectorAll('.card')[1].querySelector('a').href,/study_exam=exam-one/);
 assert.match(w.document.getElementById('content').textContent,/Awaiting submission/);
 assert.match(w.document.getElementById('content').textContent,/Assessment link needed/);
 assert.equal(writes.length,0);
 w.close();
});
test('personal EST II target stays with the selected student and course',()=>{
 const {w}=setup();w.eval("$('track').value='est2';plans[0].track_id='est2';plans[0].instructions='Personal plan: Adam\\nTarget exam: 2026-12-12';render();");
 assert.match(w.document.getElementById('planOverview').textContent,/12 Dec 2026/);
 assert.match(w.document.getElementById('satPathwayTitle').textContent,/EST II Math preparation/);
 assert(w.document.getElementById('earlierSat').hidden);
 for(const a of w.document.querySelectorAll('.pathway-links a'))assert.match(a.href,/study_track=est2/);
 w.eval("plans[0].user_id='someone-else';render();");
 assert.doesNotMatch(w.document.getElementById('planOverview').textContent,/12 Dec 2026/);
 w.close();
});
test('server completion evidence shows submitted time and read-only history',()=>{
 const {w}=setup();
 w.eval("progress[1].status='completed';progress[1].submitted_at='2026-11-05T10:30:00Z';render();");
 assert.match(w.document.querySelectorAll('.card')[1].textContent,/Completed automatically/);
 assert.match(w.document.querySelectorAll('.card')[1].textContent,/12:30/);
 w.eval("progressView=true;render();");
 assert.match(w.document.getElementById('content').textContent,/Completed automatically/);
 assert.match(w.document.getElementById('content').textContent,/Assessment link needed/);
 assert.equal(w.document.querySelectorAll('#content select').length,0);
 w.close();
});
test('missing progress evidence stays unavailable',()=>{
 const {w}=setup();
 w.eval("progress=[];render();");
 assert.match(w.document.getElementById('content').textContent,/Progress unavailable/);
 assert.doesNotMatch(w.document.getElementById('content').textContent,/Completed automatically/);
 w.close();
});
test('lesson check links use the same assessment path as practice and retests',()=>{
 const {w}=setup();
 w.eval("plans[0].lesson_exam_id='lesson-check';render();");
 assert.match(w.document.querySelector('.card a').href,/study_exam=lesson-check/);
 w.close();
});
test('returning from an assessment refreshes verified progress',()=>{
 const {w}=setup();
 w.eval("window.refreshes=0;load=async()=>{window.refreshes++;};");
 Object.defineProperty(w.document,'visibilityState',{value:'visible',configurable:true});
 w.document.dispatchEvent(new w.Event('visibilitychange'));
 assert.equal(w.refreshes,1);
 w.eval("loading=true;");
 w.document.dispatchEvent(new w.Event('visibilitychange'));
 assert.equal(w.refreshes,1);
 w.eval("loading=false;");
 const event=new w.Event('pageshow');Object.defineProperty(event,'persisted',{value:true});w.dispatchEvent(event);
 assert.equal(w.refreshes,2);
 w.close();
});
test('planner loads completion from the verified server view',async()=>{
 const {w}=setup();const tables=[];
 w.eval("window.tables=[];sb.from=table=>{window.tables.push(table);return {select(){return this},eq(){return this},gte(){return this},lte(){return this},order(){return this},range:async()=>({data:[]})};};");
 await w.load();
 assert(w.tables.includes('study_activity_completion'));
 assert(!w.tables.includes('study_activity_progress'));
 assert.match(w.document.getElementById('message').textContent,/automatically/);
 w.close();
});

test('planner reads every stable page and refuses partial success after a failed page',async()=>{
 const {w}=setup();let calls=0;
 const rows=await w.pages(()=>({range:async(start)=>{calls++;return {data:Array.from({length:start<1000?500:7},(_,i)=>({id:start+i}))};}}));
 assert.equal(rows.length,1007);assert.equal(calls,3);
 await assert.rejects(w.pages(()=>({range:async(start)=>start?{error:{message:'network failed'}}:{data:Array(500).fill({})}})),/network failed/);
 w.close();
});
test('loading another course hides old data from progress and edit actions',()=>{
 const {w}=setup();w.eval("loading=true;plans=[];progress=[];$('content').replaceChildren();progressView=true;render();");assert.equal(w.document.getElementById('content').textContent,'');w.close();
});

test('failed planner refresh cannot enable editing with a stale roster',async()=>{
 const {w}=setup();w.eval("staff=true;sb.from=()=>({select(){return this},eq(){return this},order(){return this},range:async()=>({error:{message:'network failed'}})});");
 await w.load();assert.equal(w.document.getElementById('edit').disabled,true);assert.match(w.document.getElementById('message').textContent,/Could not load/);w.close();
});
test('confirmed objective write does not hide a subsequent refresh failure',async()=>{
 const {w}=setup();const form=w.document.getElementById('planForm');
 form.elements.title.value='Systems';form.elements.instructions.value='Review two methods';form.elements.time_budget.value='30 minutes';
 w.document.getElementById('editor').close=()=>{};
 w.eval("staff=true;editorTarget={track:'sat',date:'2026-11-05',users:['one']};sb.from=()=>({upsert:row=>({select:async()=>({data:row})})});load=async()=>{message('Could not load the plan: network failed',true);return false;};");
 await form.onsubmit({preventDefault(){},target:form});
 assert.match(w.document.getElementById('message').textContent,/Could not load the plan/);assert.equal(w.document.getElementById('save').disabled,false);w.close();
});

test('skipped work is visible and Daily Quiz links retain the assigned group',()=>{
 const {w}=setup();w.eval("plans[0].practice_source='daily_quiz';plans[0].practice_group_id='group-a';progress[0].status='skipped';render();");
 assert.match(w.document.querySelector('.card').textContent,/Skipped by instructor/);
 assert.match(w.document.querySelectorAll('.card a')[1].href,/study_group=group-a/);
 assert.match(w.document.querySelectorAll('.card a')[1].href,/study_activity=daily/);
 assert.equal(w.document.querySelectorAll('#content input,#content select').length,0);w.close();
});
test('Cairo date rollover advances Today but preserves a deliberately selected historical date',()=>{
 const {w}=setup();w.eval("load=async()=>{};followToday=true;$('date').value='1900-01-01';refreshAfterReturn();");
 assert.notEqual(w.document.getElementById('date').value,'1900-01-01');
 w.eval("followToday=false;$('date').value='1900-01-01';refreshAfterReturn();");
 assert.equal(w.document.getElementById('date').value,'1900-01-01');w.close();
});

test('all math courses expose roadmaps while respecting the selected course and group',()=>{
 const {w}=setup();
 assert.deepEqual(Array.from(w.document.querySelector('#track').options,o=>o.value),['sat','est','est2','act2']);
 w.eval("members=[{group_id:'one',user_id:'one'},{group_id:'two',user_id:'one'}];groups=[{id:'one',track_id:'sat',name:'SAT class',teaching_plan:'Monday\\nSystems <script>bad</script>'},{id:'two',track_id:'est2',name:'EST II class',teaching_plan:'Circles'}];roadmap=true;render();");
 assert.match(w.document.getElementById('content').textContent,/SAT class/);
 assert.doesNotMatch(w.document.getElementById('content').textContent,/EST II class/);
 assert.equal(w.document.querySelectorAll('#content script').length,0);
 w.eval("$('track').value='est2';render();");
 assert.match(w.document.getElementById('content').textContent,/EST II class/);
 assert.equal(w.document.getElementById('revisionLink').hidden,false);assert.equal(w.document.getElementById('earlierSat').hidden,true);
 w.eval("roadmap=false;plans[0].track_id='est2';progress.forEach(p=>p.track_id='est2');render();");
 assert.match(w.document.querySelectorAll('.card')[1].querySelector('a').href,/study_track=est2/);
 w.close();
});

test('assigned tasks show exact escaped assessment titles and prominent matching links',()=>{
 const {w}=setup();
 w.eval("assignedAssessments=[{id:'exam-one',title:'Systems <18 questions>'}];render();");
 const card=w.document.querySelectorAll('.card')[1];
 assert.match(card.textContent,/ASSIGNED DAILY TASK/);
 assert.match(card.textContent,/Systems <18 questions>/);
 assert.match(card.textContent,/Other quizzes on the same topic do not count/);
 assert.match(card.querySelector('.assigned-action').href,/study_exam=exam-one/);
 assert.equal(card.querySelectorAll('questions').length,0);
 w.eval("progress[1].status='skipped';render();");
 assert.equal(w.document.querySelectorAll('.card')[1].querySelector('.assigned-action'),null);
 w.close();
});

test('calendar renders full month, selects dates, and keeps completed and skipped separate',()=>{
 const {w}=setup();w.eval("calendar=true;render();");
 assert.equal(w.document.querySelectorAll('[data-calendar-date]').length,30);
 assert.equal(w.document.getElementById('calendarTab').getAttribute('aria-pressed'),'true');
 w.document.querySelector('[data-calendar-date="2026-11-06"]').click();
 assert.equal(w.document.getElementById('date').value,'2026-11-06');
 assert.match(w.document.getElementById('content').textContent,/No objectives assigned/);
 w.eval("$('date').value='2026-11-05';progress[0].status='skipped';progress[1].status='completed';render();");
 assert.match(w.document.getElementById('planOverview').textContent,/1 skipped/);
 assert.equal(w.dayCounts('2026-11-05').completed,1);assert.equal(w.dayCounts('2026-11-05').skipped,1);
 w.close();
});
test('future Alex recurrence is marked unverified until the actual dated assignment is available',()=>{
 const {w}=setup();w.eval("$('track').value='est';$('date').value='2026-11-10';groups=[{id:alexSchedule.group,track_id:'est',name:'Alex'}];members=[{group_id:alexSchedule.group,user_id:'one'}];calendar=true;render();");
 assert.match(w.document.getElementById('planChecks').textContent,/dated assessment is not yet visible/);
 w.eval("scheduleVerified=true;scheduleAssignments=[{id:'a',group_id:alexSchedule.group,exam_id:'e',open_at:'2026-11-10T11:10:00Z',close_at:'2026-11-10T11:30:00Z',exams:{title:'Alex — Tuesday Algebra',duration_seconds:1200}}];render();");
 assert.doesNotMatch(w.document.getElementById('planChecks').textContent,/dated assessment is not yet visible/);
 assert.match(w.document.querySelector('.calendar-agenda').textContent,/13:10/);
 assert.match(w.document.querySelector('.calendar-agenda a').href,/study_exam=e/);
 w.close();
});
test('schedule conflict checks require overlapping windows for the same student, exclude duplicate exam assignments',()=>{
 const {w}=setup();w.eval("scheduleVerified=true;assessmentMetadataVerified=true;scheduleAssignments=[{id:'a',user_id:'one',exam_id:'exam-one',open_at:'2026-11-05T11:00:00Z',close_at:'2026-11-05T11:30:00Z',exams:{title:'First'}},{id:'b',user_id:'two',exam_id:'exam-two',open_at:'2026-11-05T11:00:00Z',close_at:'2026-11-05T11:30:00Z',exams:{title:'Second'}}];render();");
 assert.doesNotMatch(w.document.getElementById('planChecks').textContent,/Possible schedule conflict/);
 w.eval("scheduleAssignments[1].user_id='one';render();");assert.match(w.document.getElementById('planChecks').textContent,/Possible schedule conflict/);
 w.eval("scheduleAssignments[1].exam_id='exam-one';render();");assert.doesNotMatch(w.document.getElementById('planChecks').textContent,/Possible schedule conflict/);
 w.close();
});
test('assignment validation flags outside-window and missing assignment links without creating assignments',()=>{
 const {w,writes}=setup();w.eval("scheduleVerified=true;assessmentMetadataVerified=true;assignedAssessments=[{id:'exam-one',title:'Exam'}];scheduleAssignments=[{user_id:'one',exam_id:'exam-one',open_at:'2026-11-06T11:00:00Z',close_at:'2026-11-06T12:00:00Z'}];render();");
 assert.match(w.document.getElementById('planChecks').textContent,/outside its assignment window/);
 w.eval("scheduleAssignments=[];render();");assert.match(w.document.getElementById('planChecks').textContent,/no visible assignment/);assert.equal(writes.length,0);w.close();
});
test('student calendar and exam targets exclude groups the student does not belong to',()=>{
 const {w}=setup();w.eval("groups=[{id:'mine',track_id:'sat',name:'My group',target_exam_date:'2026-12-05'},{id:'other',track_id:'sat',name:'Other group',target_exam_date:'2026-12-11'}];members=[{group_id:'mine',user_id:'one'}];roadmap=true;render();");
 assert.match(w.document.getElementById('planOverview').textContent,/5 Dec 2026/);
 assert.doesNotMatch(w.document.getElementById('content').textContent,/Other group/);
 assert.equal(w.document.querySelector('[data-roadmap-edit]'),null);w.close();
});
test('group roadmap publishes through the guarded RPC and preserves course and assessment settings',async()=>{
 const {w}=setup();w.document.getElementById('roadmapEditor').showModal=()=>{};w.document.getElementById('roadmapEditor').close=()=>{};
 w.eval("staff=true;ready=true;groups=[{id:'group',track_id:'sat',name:'SAT',teaching_plan:'Before',plan_version:4,course_starts_on:'2026-10-01',course_ends_on:'2026-12-31',daily_lessons:['Systems']}];window.calls=[];sb.rpc=async(name,args)=>{window.calls.push({name,args});return {data:{}}};load=async()=>true;");
 await w.editRoadmap('group');const form=w.document.getElementById('roadmapForm');form.elements.teaching_plan.value='After';form.elements.target_exam_date.value='2026-12-05';await form.onsubmit({preventDefault(){},target:form});
 assert.equal(w.calls.length,1);assert.equal(w.calls[0].name,'staff_save_group_plan');assert.equal(w.calls[0].args.p_expected_version,4);
 assert.equal(w.calls[0].args.p_data.course_ends_on,'2026-12-31');assert.equal(w.calls[0].args.p_data.daily_lessons[0],'Systems');assert.equal(w.calls[0].args.p_data.teaching_plan,'After');w.close();
});
test('bulk publishing cannot silently replace existing personal objectives',async()=>{
 const {w,writes}=setup();w.eval("staff=true;editorTarget={track:'sat',date:'2026-11-05',users:['one','two'],replacing:true};");const form=w.document.getElementById('planForm');await form.onsubmit({preventDefault(){},target:form});assert.match(w.document.getElementById('saveError').textContent,/acknowledge replacement/);assert.equal(writes.length,0);w.close();
});
test('calendar month navigation reloads data and correctly crosses a year boundary',async()=>{
 const {w}=setup();w.eval("$('date').value='2026-12-31';window.loads=0;load=async()=>{window.loads++};");await w.changeMonth(1);assert.equal(w.document.getElementById('date').value,'2027-01-01');assert.equal(w.loads,1);w.close();
});

test('SAT pathway uses saved target, visible memberships and links to the December revision hub',()=>{
 const {w}=setup();w.eval("groups=[{id:'mine',track_id:'sat',name:'Sat nov and dec',target_exam_date:'2026-12-05'},{id:'other',track_id:'sat',name:'Hidden group'}];members=[{group_id:'mine',user_id:'one'}];plans[0].instructions='Group: Sat nov and dec\\nReview systems';render();");
 assert.match(w.document.getElementById('satPathwayTitle').textContent,/5 Dec 2026/);assert.match(w.document.getElementById('planOverview').textContent,/Portal groups: Sat nov and dec/);assert.doesNotMatch(w.document.getElementById('planOverview').textContent,/Hidden group/);
 assert(w.document.querySelector('#revisionLink #earlierSat a[href="/sat-revision.html"]'));
 assert.match(w.document.querySelector('.card a').href,/study_date=2026-11-05/);w.close();
});
test('roadmap without a dated objective explicitly warns of the missing daily work',()=>{
 const {w}=setup();w.eval("$('date').value=today();plans=[];groups=[{id:'mine',track_id:'sat',name:'SAT',target_exam_date:'2099-12-05'}];members=[{group_id:'mine',user_id:'one'}];render();");assert.match(w.document.getElementById('planChecks').textContent,/roadmap does not automatically create/);assert.match(w.document.getElementById('content').textContent,/No objectives assigned/);w.close();
});

test('study date shows paused, expired and unverified course access without changing enrolment',()=>{
 const {w,writes}=setup();w.eval("enrollmentVerified=true;enrollmentWindows=[{user_id:'one',track_id:'sat',status:'paused'}];render();");
 assert.match(w.document.getElementById('planChecks').textContent,/not active/);
 w.eval("enrollmentWindows[0].status='active';enrollmentWindows[0].ends_at='2026-11-04T22:51:00Z';render();");
 assert.match(w.document.getElementById('planChecks').textContent,/5 Nov, 00:51|5 Nov.*00:51/);
 assert.match(w.document.getElementById('planChecks').textContent,/may be unavailable/);
 w.eval("enrollmentVerified=false;render();");assert.match(w.document.getElementById('planChecks').textContent,/access dates could not be verified/);
 assert.equal(writes.length,0);w.close();
});

test('EST study plans link to their matching revision course and hide that link on SAT and ACT2',()=>{
 const {w}=setup();
 for(const track of ['est','est2']){w.eval("$('track').value='"+track+"';render();");assert.equal(w.document.getElementById('estRevision').hidden,false);assert.equal(new URL(w.document.getElementById('estRevisionLink').href).searchParams.get('track'),track);}
 for(const track of ['sat','act2']){w.eval("$('track').value='"+track+"';render();");assert.equal(w.document.getElementById('estRevision').hidden,true);}
 w.close();
});

test('plan coverage scopes students and distinguishes missing dates from pending work',()=>{
 const {w}=setup();w.eval("plans.push({...plans[0],user_id:'other',title:'Private other plan'});renderCoverage();");
 const text=w.document.getElementById('planCoverage').textContent;assert.match(text,/6 unplanned dates/);assert.match(text,/Target unverified/);assert.match(text,/not pending work/);assert.doesNotMatch(text,/Private other plan/);w.close();
});

test('planner URL keeps date and course context without granting another student access',()=>{
 const {w}=setup();w.eval("initialContextPending=false;followToday=false;calendar=true;render();");
 const params=new URL(w.location.href).searchParams;assert.equal(params.get('track'),'sat');assert.equal(params.get('view'),'calendar');assert.equal(params.get('date'),'2026-11-05');assert.equal(params.get('student'),null);w.close();
});

test('calendar queries include the entire selected month at a boundary',async()=>{
 const {w}=setup();w.eval("$('date').value='2027-01-31';window.starts=[];sb.from=table=>({select(){return this},eq(){return this},gte(k,v){if(table==='student_daily_objectives')window.starts.push(v);return this},lte(){return this},order(){return this},range:async()=>({data:[]})});");
 await w.load();assert(w.starts.includes('2027-01-01'));w.close();
});
