const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const {JSDOM}=require('./english-runtime/node_modules/jsdom');
const read=f=>fs.readFileSync('web/'+f,'utf8');
function student(track='sat'){
 const dom=new JSDOM('<div id="dashboardContent"></div>',{runScripts:'outside-only'}),w=dom.window;
 w.ST={track:{id:track,name:track}};w.DASH={view:'finalsDiagnosis',history:[],exams:[],lessons:[{lesson:'Circles',seen:3,correct:1,percent:33,priority:'focus'}],repeatQuestions:2};
 w.REV={track,data:{items:[]},collection:'repeated',level:'hard',scope:'est',source:'est',mode:'formulas',session:{id:'saved'}};
 w.esc=s=>String(s??'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));w.paintDashboard=()=>{};w.paintDashboardContent=()=>{};w.wireDashboard=()=>{};w.math=()=>{};w.refreshRevision=async()=>{};w.revisionPaint=()=>{};w.setDashboardView=v=>w.DASH.view=v;
 w.sb={from:()=>{throw new Error('Must use course-scoped server repeat count');}};
 w.eval(read('portal-controls.js').slice(read('portal-controls.js').indexOf('function finalsExamLessons')));w.paintDashboardContent();
 return {dom,w,d:w.document};
}
for(const track of ['sat','est','est2'])test('diagnosed lesson clears old filters and opens the lesson without replacing saved practice in '+track,async()=>{
 const f=student(track);try{const saved={id:'saved',questions:[{response:'B'}]};f.w.REV.data.session=saved;
 await f.d.querySelector('[data-diagnosis-revision]').onclick();
 assert.equal(f.w.REV.collection,'all');assert.equal(f.w.REV.level,'mixed');assert.equal(f.w.REV.scope,'both');assert.equal(f.w.REV.source,track==='sat'?'both':track);assert.equal(f.w.REV.lesson,'Circles');assert.equal(f.w.REV.mode,'questions');assert.equal(f.w.REV.session,null);assert.equal(f.w.REV.data.session,saved,'unfinished server set stays resumable');
 }finally{f.dom.window.close();}
});
test('strong lessons are maintained, daily group scores stay separate, and repeats are course-scoped',()=>{
 const f=student();try{f.w.DASH.lessons=[{lesson:'Circles',classified:true,seen:4,correct:4,percent:100}];f.w.DASH.dailyGroups=[{group_name:'Class A',latest_score:5,average_score:5,latest_day:'2026-10-15',completed:1},{group_name:'Class B',latest_score:0,average_score:0,latest_day:'2026-10-15',completed:1}];f.w.paintDashboardContent();
 assert.match(f.d.body.textContent,/sufficiently assessed lessons are strong/);assert.equal(f.d.querySelectorAll('[data-diagnosis-revision]').length,0);assert.match(f.d.body.textContent,/Class A5\/5.*Class B0\/5/);assert.match(f.d.body.textContent,/2 active repeat-error questions/);assert.equal(f.w.DASH.lessons[0].percent,100);
 }finally{f.dom.window.close();}
});
test('attempt with no saved answers retains its grade and cannot generate lesson weaknesses',async()=>{
 const f=student();try{
 f.w.DASH.history=[{id:'empty',exam_id:'e',title:'Empty diagnostic',assessment_type:'full_exam',score:0,total:44,percent:0,review_open:true,answered_count:0,attempt_no:1}];
 f.w.fn=async()=>({ok:true,json:{exam:{track_id:'sat'},review_open:true,items:[{id:'q',topic:'Circles',is_correct:false}]}});f.w.paintDashboardContent();await f.d.querySelector('[data-diagnosis-exam]').onclick();
 assert.match(f.d.querySelector('.diagnosis-exams').textContent,/No saved answers/);assert(!f.d.querySelector('.diagnosis-exams').textContent.includes('1 missed'));assert.match(f.d.body.textContent,/0\/44/);
 }finally{f.dom.window.close();}
});
test('held and removed reviewed items cannot enter a lesson plan',()=>{
 const f=student();try{assert.equal(f.w.finalsExamLessons([{id:'hold',topic:'Circles',is_correct:false,assets:{release_hold_reason:'Review'}},{id:'removed',topic:'Circles',is_correct:false,assets:{bank_removed:'true'}}]).length,0);}finally{f.dom.window.close();}
});
test('missing revision lesson states its name and has no enabled practice button',()=>{
 const f=student();try{f.w.figure=()=>'';f.w.eval(read('final-revision.js').slice(0,read('final-revision.js').indexOf('function revisionSessionPanel'))+"\nREV={track:'sat',data:{items:[]},session:null,collection:'all',scope:'both',source:'both',lesson:'Missing lesson',level:'mixed'};document.body.innerHTML=revisionPanel();");
 assert.match(f.d.body.textContent,/No released revision questions.*Missing lesson/);assert([...f.d.querySelectorAll('[data-revision-start]')].every(b=>b.disabled));
 }finally{f.dom.window.close();}
});

test('refresh diagnosis reloads exam evidence and separate group scores without submitting anything',async()=>{
 const f=student();try{let request;f.w.fn=async(name,args)=>{request={name,args};return {ok:true,json:{dashboard:{history:[],lessons:[{lesson:'Functions',seen:3,correct:0,percent:0}],daily_groups:[{group_name:'Class B',latest_score:1,average_score:1,latest_day:'2026-10-15',completed:1}],repeat_questions:0}}};};
 await f.d.querySelector('[data-diagnosis-refresh]').onclick();assert.equal(request.name,'me-tracks');assert.equal(request.args.qs,'?track=sat');assert.equal(request.args.method,undefined);assert.match(f.d.body.textContent,/Functions.*0%/s);assert.match(f.d.body.textContent,/Class B1\/5/);assert.match(f.d.body.textContent,/0 active repeat-error questions/);
 }finally{f.dom.window.close();}
});
test('late diagnosis refresh cannot overwrite another course',async()=>{
 const f=student();try{let release;f.w.fn=()=>new Promise(r=>release=r);const pending=f.d.querySelector('[data-diagnosis-refresh]').onclick();f.w.ST.track={id:'est2'};f.w.DASH.history=[];f.w.DASH.lessons=[{lesson:'Vectors',seen:3,correct:1,percent:33}];f.w.paintDashboardContent();release({ok:true,json:{dashboard:{history:[],lessons:[{lesson:'Old SAT result',seen:9,percent:0}]}}});await pending;assert.match(f.d.body.textContent,/Vectors/);assert(!f.d.body.textContent.includes('Old SAT result'));
 }finally{f.dom.window.close();}
});
test('concurrent revision opening shares a request and applies lesson selection after it completes',async()=>{
 const f=student();try{let release,calls=0;f.w.fn=()=>{calls++;return new Promise(r=>release=r);};f.w.friendly=String;
 f.w.eval("paintDashboard=()=>{};paintDashboardContent=()=>{};\n"+read('final-revision.js').slice(0,read('final-revision.js').indexOf('function revisionSessionPanel'))+'\n'+read('portal-controls.js').slice(read('portal-controls.js').indexOf('function finalsExamLessons'))+"\nwindow.revisionState=()=>REV;setDashboardView=v=>{DASH.view=v;refreshRevision();};paintDashboardContent();");
 const click=f.d.querySelector('[data-diagnosis-revision]').onclick();assert.equal(calls,1);assert.equal(f.w.revisionState().loading,true);
 const saved={id:'saved',questions:[{response:'B'}]};release({ok:true,json:{items:[],session:saved}});await click;
 assert.equal(calls,1);assert.equal(f.w.revisionState().lesson,'Circles');assert.equal(f.w.revisionState().session,null);assert.equal(f.w.revisionState().data.session,saved);
 }finally{f.dom.window.close();}
});

test('instructor timeout keeps course selection and retry recovers the report',async()=>{
 const dom=new JSDOM('<div id="view"></div>',{runScripts:'outside-only'}),w=dom.window;
 try{
  w.ST={view:'finalsDiagnosisAdmin',track:'est'};w.render=()=>{};w.syncAdminNavigation=()=>{};w.csv=()=>{};
  let calls=0;w.sb={rpc:async()=>++calls===1?{error:{code:'57014',message:'canceling statement due to statement timeout'}}:{data:{track_id:w.ST.track,students:[]}}};
  w.eval(read('hardest-questions.js'));await new Promise(r=>w.setTimeout(r,10));await w.render();
  assert.match(w.document.querySelector('[role="alert"]').textContent,/took too long/);
  assert.equal(w.document.getElementById('diagnosisTrack').value,'est');assert.equal(calls,1);
  await w.document.getElementById('finalsDiagnosisRetry').onclick();
  assert.equal(calls,2);assert(w.document.getElementById('finalsDiagnosisRefresh'));assert(!w.document.querySelector('[role="alert"]'));
 }finally{dom.window.close();}
});
test('late instructor timeout cannot overwrite a different course',async()=>{
 const dom=new JSDOM('<div id="view"></div>',{runScripts:'outside-only'}),w=dom.window;
 try{
  w.ST={view:'finalsDiagnosisAdmin',track:'est'};w.render=()=>{};w.syncAdminNavigation=()=>{};
  let release;w.sb={rpc:()=>new Promise(r=>release=r)};
  w.eval(read('hardest-questions.js'));await new Promise(r=>w.setTimeout(r,10));const pending=w.render();
  w.ST.track='sat';w.document.getElementById('view').textContent='SAT report';release({error:{code:'57014'}});await pending;
  assert.equal(w.document.getElementById('view').textContent,'SAT report');
 }finally{dom.window.close();}
});
