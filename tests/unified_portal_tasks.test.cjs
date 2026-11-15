const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {JSDOM}=require('./english-runtime/node_modules/jsdom');
const html=fs.readFileSync('web/index.html','utf8');
function setup(query='?study_track=sat&study_exam=assigned&study_task=lesson&study_date=2026-11-14'){
 const dom=new JSDOM(html,{url:'https://portal.test/'+query,runScripts:'outside-only'}),w=dom.window;
 const context=dom.getInternalVMContext();w.eval=code=>vm.runInContext(code,context);
 w.scrollTo=()=>{};w.setInterval=()=>0;w.PortalSession={restore:async()=>{}};
 const auth={getSession:async()=>({data:{session:null}})};
 w.supabase={createClient:()=>({auth,rpc:async()=>({data:[{track_id:'sat',practice_open:true}]})})};
 w.eval(fs.readFileSync('web/daily-challenge.js','utf8'));
 w.eval(html.split('<script>')[1].split('</script>')[0]);
 w.eval("displayStudyObjective=async()=>{};resetRevision=()=>{};reportButton=()=>'';wireReports=()=>{};wireRevision=()=>{};wireFormulas=()=>{};ST.tracks=[{id:'sat',name:'SAT Math'}];REV={data:null};");
 w.StudentWork={panel:()=>'',wire(){},shortcuts:()=>''};w.PortalMath={render(){}};
 w.serverExams=[{id:'assigned',title:'Exact assigned lesson',assessment_type:'lesson_exam',questions:3,duration_seconds:600,open:true}];w.calls=[];
 w.eval("fn=async(name,options)=>{calls.push({name,options});if(name==='me-tracks')return {ok:true,json:{exams:serverExams,dashboard:{history:[],lessons:[],summary:{}}}};if(name==='portal-controls')return {ok:true,json:{revision_visible:true}};throw Error('Unexpected API '+name);};");
 return {dom,w,d:w.document};
}
const flush=()=>new Promise(resolve=>setImmediate(resolve));
test('exact task survives an already pending Daily Quiz response and every repaint',async()=>{
 const f=setup();try{
  f.w.eval("ST.track=ST.tracks[0];DASH.view='daily';");
  let resolve;const original=f.w.eval('fn');f.w.delayedQuizResponse=new Promise(r=>resolve=r);
  f.w.originalFn=original;f.w.eval("fn=(name,options)=>name==='daily-challenge'?delayedQuizResponse:originalFn(name,options)");
  const pending=f.w.refreshDaily();await f.w.openStudyLink();
  assert.equal(f.w.eval('DASH.view'),'assigned_task');assert.equal(f.d.querySelectorAll('[data-start="assigned"]').length,1);
  assert.equal(f.d.activeElement.id,'dashboardContent');
  resolve({ok:true,json:{track:'sat',date:'2026-11-14',scope_id:'group'}});await pending;
  assert.match(f.d.getElementById('dashboardContent').textContent,/Exact assigned lesson/);
  f.w.paintDashboardContent();assert.equal(f.d.querySelectorAll('[data-start="assigned"]').length,1);
  assert.equal(f.w.calls.filter(x=>x.name==='start-attempt').length,0);
  assert.equal(f.w.calls.filter(x=>x.name==='daily-challenge').length,0,'Opening an assignment must not launch another quiz request');
  f.w.setDashboardView('assignments');assert.equal(f.d.querySelector('.assigned-daily-panel'),null);
 }finally{f.dom.window.close();}
});
test('closed and held assignments and missing module prerequisites keep the original start gate',async()=>{
 for(const patch of [{open:false},{content_ready:false},{module_number:2,exam_set_code:'missing-first'}]){
  const f=setup();try{Object.assign(f.w.serverExams[0],patch);await f.w.openStudyLink();assert(f.d.querySelector('[data-start]').disabled);}finally{f.dom.window.close();}
 }
});
test('starting an assignment uses the existing handler once and preserves the chosen timer',async()=>{
 const f=setup();try{
  await f.w.openStudyLink();const calls=[];f.w.startExam=async(...args)=>calls.push(args);
  f.d.querySelector('[data-timer]').value='timed';f.d.querySelector('[data-start]').click();await flush();
  assert.deepEqual(calls,[['assigned',false]]);
 }finally{f.dom.window.close();}
});
test('a retry after catalog failure keeps the exact assignment destination',async()=>{
 const f=setup();try{
  f.w.eval("openTrack=async()=>{document.getElementById('examList').innerHTML='<button id=\"retryDashboard\">Retry</button>';};");
  await f.w.openStudyLink();assert(f.d.getElementById('retryDashboard').onclick);
 }finally{f.dom.window.close();}
});
test('dated and wrong-group quiz links do not offer submission for a different task',()=>{
 const f=setup();try{
  f.w.eval("ST.track=ST.tracks[0];DASH.dailyTarget={date:'2000-01-01',group:'assigned-group'};DASH.daily={date:'2026-11-14',scope_id:'other-group'};");
  assert.match(f.w.dailyPanel(),/will not complete that dated task/);assert.doesNotMatch(f.w.dailyPanel(),/data-daily-submit/);
  f.w.eval("DASH.dailyTarget.date='';");assert.match(f.w.dailyPanel(),/assigned group/);assert.doesNotMatch(f.w.dailyPanel(),/data-daily-submit/);
  f.w.eval("DASH.dailyTarget=null;DASH.daily=null;setDashboardView('assignments');");assert.equal(f.w.eval('DASH.dailyTarget'),null);
 }finally{f.dom.window.close();}
});
test('Today exposes all three exact activity links and omits instructor-skipped activities',async()=>{
 const dom=new JSDOM('<div id="chooserObjective"></div><div id="dashboardObjective"></div>',{url:'https://portal.test/',runScripts:'outside-only'}),w=dom.window;
 try{
 const date=new Intl.DateTimeFormat('en-CA',{timeZone:'Africa/Cairo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
 const plan={user_id:'fixture',track_id:'est2',study_date:date,title:'Geometry',lesson_exam_id:'lesson',practice_exam_id:'practice',retest_exam_id:'retest',skipped_activities:[]};
 Object.assign(w,{$:id=>w.document.getElementById(id),ST:{track:{id:'est2'},tracks:[{id:'est2'}]},displayWeeklyObjective(){},setInterval(){},sb:{from:table=>({select(){return this},eq(){return this},in:async()=>({data:table==='student_daily_objectives'?[plan]:[]})})}});
 w.eval(html.slice(html.indexOf('let objectiveRequest'),html.indexOf('function show(id)')));await w.displayStudyObjective('vList');
 const ids=()=>[...w.document.querySelectorAll('.today-activity-links a')].map(a=>new URL(a.href).searchParams.get('study_exam'));
 assert.deepEqual(ids(),['lesson','practice','retest']);plan.skipped_activities=['lesson'];await w.displayStudyObjective('vList');assert.deepEqual(ids(),['practice','retest']);
 }finally{dom.window.close();}
});
test('sign-in return accepts only the existing local workspaces and retains the exact selection',()=>{
 for(const [value,expected] of [['/study-plan.html?track=est2&date=2026-11-18','/study-plan.html?track=est2&date=2026-11-18'],['/practice-bundles.html?track=sat&bundle=sample','/practice-bundles.html?track=sat&bundle=sample'],['https://evil.test',null],['//evil.test/study-plan.html',null],['/\\evil.test/study-plan.html',null],['/admin.html',null],['/unknown',null],['javascript:alert(1)',null]]){
  const dom=new JSDOM('',{runScripts:'outside-only',url:'https://portal.test/?'+new URLSearchParams({return_to:value})});try{dom.window.eval(fs.readFileSync('web/portal-return.js','utf8'));assert.equal(dom.window.PortalReturn.target(),expected);}finally{dom.window.close();}
 }
});
test('practice and correction navigation follows all supported course selections and staff role',()=>{
 for(const page of ['practice','checkpoint']){
 const dom=new JSDOM('<body data-portal-page="'+page+'"><header><a id="portalBack" href="/">Back</a></header><select id="course"><option value="est2">EST II</option><option value="sat_eng">SAT English</option></select></body>',{runScripts:'outside-only',url:'https://portal.test/'}),w=dom.window,d=w.document;
 try{
  w.eval(fs.readFileSync('web/portal-navigation.js','utf8'));
  assert.equal(d.querySelector('.portal-primary a[href="/?study_track=est2&study_activity=quiz"]').textContent,'Quizzes');
  assert(d.querySelector('a[href="/?study_track=est2&study_activity=focus"]'));
  d.getElementById('course').value='sat_eng';d.getElementById('course').dispatchEvent(new w.Event('change'));
  assert(d.querySelector('.portal-primary a[href="/?study_track=sat_eng&study_activity=quiz"]'));assert.equal(d.querySelector('.portal-primary a[href^="/study-plan.html"]'),null);
  d.body.dataset.portalRole='staff';d.dispatchEvent(new w.Event('portal-context'));assert(d.querySelector('.portal-primary a[href="/admin.html?section=results&track=sat_eng"]'));
 }finally{dom.window.close();}
 }
});
test('Teaching Studio opens the existing teaching dashboard only after staff authorization',()=>{
 const source=fs.readFileSync('web/admin.html','utf8'),code=source.slice(source.indexOf('function applyPlannerDestination()'),source.indexOf('async function notifications()'));
 for(const role of ['student','instructor','admin']){
  const dom=new JSDOM('<button data-v="teachingDashboard">Teaching dashboard</button>',{runScripts:'outside-only',url:'https://portal.test/admin.html?section=teachingDashboard'}),w=dom.window;
  try{w.ST={view:'overview',me:{role},tracks:[]};w.$=id=>w.document.getElementById(id);w.eval(code);w.applyPlannerDestination();assert.equal(w.ST.view,role==='student'?'overview':'teachingDashboard');}finally{dom.window.close();}
 }
});
