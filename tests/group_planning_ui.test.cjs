const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const {JSDOM}=require('./english-runtime/node_modules/jsdom');
const source=fs.readFileSync('web/hardest-questions.js','utf8');
const roster='abcdefg'.split('').map(user_id=>({user_id,role:'student',full_name:'Student '+user_id,tracks:'est'}));
const lessons=['Circles','Linear equations','Statistics'].flatMap((lesson,i)=>['abcdef'[2*i],'abcdef'[2*i+1]].flatMap(user_id=>[
 {user_id,lesson,questions_seen:3,percent:20+i*10},{user_id,lesson:'Functions',questions_seen:3,percent:90}
]));
async function report({failure=false,visible=true,ready=true,delay=null,rpc=null}={}){
 const dom=new JSDOM('<nav class="tabs"><div class="wrap"></div></nav><div id="view"></div>',{runScripts:'outside-only',url:'http://localhost/'});
 const w=dom.window,reads=[],actions=[];
 w.ST={view:'finalsDiagnosisAdmin'};w.render=()=>{};w.syncAdminNavigation=()=>{};w.csv=()=>{};
 const fixtures={roster,student_by_lesson:lessons,results_feed:[],groups:[{id:'seven',name:'Seven',track_id:'est'}],group_members:roster.map(x=>({group_id:'seven',user_id:x.user_id})),exams:[{id:'retest',title:'EST I Final Weakness Retest — Oct 2026',is_published:true,track_id:'est',question_ids:Array(25).fill('q'),duration_seconds:2100,assessment_type:'lesson_exam'},{id:'exam2',title:'Second exam',track_id:'est',assessment_type:'full_exam'}]};
 w.q=table=>{let bounds=[0,499];const query={eq:()=>query,order:()=>query,range:(a,b)=>{bounds=[a,b];return query;},then:async resolve=>{
   reads.push(table);if(delay&&table==='groups')await delay;
   return resolve(failure&&['groups','group_members','exams'].includes(table)?{error:new Error('Offline')}:{data:(fixtures[table]||[]).slice(bounds[0],bounds[1]+1)});
 }};return query;};
 w.portalControl=async(action,data)=>{actions.push({action,data});if(failure)throw new Error('Offline');return {visible,items:['Circles','Linear equations','Statistics'].map(lesson=>({lesson,active:true,ready}))};};
 w.sb={rpc:async(name,data)=>{actions.push({action:name,data});return rpc?rpc(name,data):{data:{exam_id:data.p_exam,track_id:'est',students:[]}};}};
 w.eval(source);await new Promise(resolve=>w.setTimeout(resolve,10));await w.render();
 return {dom,w,reads,actions,open:()=>w.document.getElementById('finalsGroupView').onclick()};
}
test('group view switches, selects the real class and only reads evidence and resources',async()=>{
 const f=await report();try{
  assert.equal(f.reads.length,3,'resources are loaded only when group planning opens');await f.open();
  const d=f.w.document,p=d.getElementById('finalsGroupPlan');
  assert.equal(d.getElementById('finalsClass').value,'seven');assert.equal(p.querySelectorAll('.finals-cluster').length,3);
  assert.match(p.textContent,/7 students selected/);assert.match(p.querySelector('.finals-insufficient').textContent,/Student g/);
  assert(!p.querySelector('.finals-clusters').textContent.includes('Student g'));assert.match(p.textContent,/25 questions · 35 minutes/);
  d.getElementById('finalsStudentsView').onclick();assert.equal(d.getElementById('finalsGroup').hidden,true);await f.open();
  assert.equal(f.reads.length,6,'switching views must reuse the loaded resources');assert.equal(f.actions.length,1);assert.equal(f.actions[0].action,'revision.list');assert.equal(f.actions[0].data.track,'est');
  const member=d.querySelector('[data-finals-student="a"]');member.checked=false;member.onchange();
  assert.match(p.textContent,/6 students selected/);assert.equal(p.querySelectorAll('.finals-cluster').length,2);
  assert.equal(f.w.localStorage.length,0);assert.equal(f.w.sessionStorage.length,0);
 }finally{f.dom.window.close();}
});
for(const config of [{visible:false},{ready:false},{failure:true}])test('unavailable resources stay explicit '+JSON.stringify(config),async()=>{
 const f=await report(config);try{await f.open();const d=f.w.document,p=d.getElementById('finalsGroupPlan');
  assert.equal(p.querySelectorAll('.finals-cluster').length,3);assert.equal(p.querySelectorAll('[data-finals-revision]').length,0);
  assert.match(p.textContent,config.failure?/availability could not be checked/:config.visible===false?/hidden from students/:/No released, ready/);
  if(config.failure)assert.equal(p.querySelectorAll('[data-finals-retest]').length,0);
 }finally{f.dom.window.close();}
});
test('late group data cannot overwrite a different instructor section',async()=>{
 let release;const delay=new Promise(resolve=>release=resolve),f=await report({delay});
 try{const pending=f.open();f.w.ST.view='results';f.w.document.getElementById('view').textContent='Other section';release();await pending;assert.equal(f.w.document.getElementById('view').textContent,'Other section');}finally{f.dom.window.close();}
});

const examStudent=(user_id,state='available',lesson='Triangles')=>({user_id,state,attempt:state==='available'?{id:'attempt-'+user_id,attempt_no:2,submitted_at:'2026-10-04T10:00:00Z'}:null,lessons:state==='available'?[
 {lesson,classified:true,seen:4,correct:3,missed:1,blank:1,percent:75},
 {lesson:'Functions',classified:true,seen:3,correct:3,missed:0,blank:0,percent:100},
 {lesson:'Limited',classified:true,seen:1,correct:0,missed:1,blank:0,percent:0},
 {lesson:'Unclassified questions',classified:false,seen:3,correct:0,missed:3,blank:0,percent:0}
]:[]});
const response=(data,lesson='Triangles')=>({data:{exam_id:data.p_exam,track_id:'est',students:data.p_students.map((id,i)=>examStudent(id,i<2?'available':i===2?'locked':i===3?'ungraded':i===4?'missing':'available',lesson))}});
async function choose(f,value){const s=f.w.document.getElementById('finalsEvidenceScope');s.value=value;s.onchange({target:s});await new Promise(r=>setImmediate(r));}
test('selected exam replaces overall weaknesses, counts misses above 60%, and separates missing and locked evidence',async()=>{
 const f=await report({rpc:async(_,data)=>response(data)});try{await f.open();await choose(f,'retest');
 const d=f.w.document,p=d.getElementById('finalsGroupPlan');
 assert.match(p.textContent,/Triangles/);assert(!p.querySelector('.finals-common').textContent.includes('Circles'));
 assert.equal(p.querySelectorAll('.finals-cluster').length,1);assert.match(p.querySelector('.finals-common').textContent,/75%/);
 assert.match(p.querySelector('.finals-insufficient').textContent,/Student c.*locked/s);
 assert.match(p.querySelector('.finals-insufficient').textContent,/Student d.*awaiting grading/s);
 assert.match(p.querySelector('.finals-insufficient').textContent,/Student e.*No completed scored attempt/s);
 assert.match(p.textContent,/Attempt 2/);assert.match(p.textContent,/Limited evidence: fewer than 3/);assert.match(p.textContent,/Unclassified; teacher review/);
 const call=f.actions.find(x=>x.action==='staff_group_exam_evidence');assert.equal(call.data.p_exam,'retest');assert.equal(call.data.p_students.join(''),'abcdefg');
 const member=d.querySelector('[data-finals-student="a"]');member.checked=false;member.onchange();await new Promise(r=>setImmediate(r));
 assert.equal(f.actions.filter(x=>x.action==='staff_group_exam_evidence').length,2);assert(!f.actions.at(-1).data.p_students.includes('a'));
 await choose(f,'');assert.match(p.querySelector('.finals-common').textContent,/Circles/);assert.equal(p.querySelectorAll('.finals-cluster').length,2);
 assert.equal(f.w.localStorage.length,0);
 }finally{f.dom.window.close();}
});
test('failed and incomplete exam reads never fall back to overall evidence and retry safely',async()=>{
 let calls=0;const f=await report({rpc:async(_,data)=>{calls++;if(calls===1)throw new Error('Offline');if(calls===2)return {data:{exam_id:data.p_exam,track_id:'est',students:[]}};return response(data);}});
 try{await f.open();await choose(f,'retest');const d=f.w.document,p=d.getElementById('finalsGroupPlan');assert.match(p.textContent,/Could not load/);assert(!p.textContent.includes('Circles'));
 await d.getElementById('finalsExamRetry').onclick();assert.match(p.textContent,/Could not load/);
 await d.getElementById('finalsExamRetry').onclick();assert.match(p.textContent,/Triangles/);
 }finally{f.dom.window.close();}
});
test('late exam requests cannot overwrite a newer scope, membership or page',async()=>{
 const pending=[];const f=await report({rpc:(_,data)=>new Promise(resolve=>pending.push({data,resolve}))});
 try{await f.open();await choose(f,'retest');await choose(f,'exam2');assert.equal(pending.length,2);
 pending[1].resolve(response(pending[1].data,'New exam'));await new Promise(r=>setImmediate(r));
 pending[0].resolve(response(pending[0].data,'Old exam'));await new Promise(r=>setImmediate(r));
 const d=f.w.document,p=d.getElementById('finalsGroupPlan');assert.match(p.textContent,/New exam/);assert(!p.textContent.includes('Old exam'));
 const member=d.querySelector('[data-finals-student="a"]');member.checked=false;member.onchange();await choose(f,'');pending[2].resolve(response(pending[2].data,'Stale membership'));await new Promise(r=>setImmediate(r));assert(!p.textContent.includes('Stale membership'));assert.match(p.textContent,/6 students selected/);
 await choose(f,'retest');f.w.ST.view='results';d.getElementById('view').textContent='Other page';pending[3].resolve(response(pending[3].data));await new Promise(r=>setImmediate(r));assert.equal(d.getElementById('view').textContent,'Other page');
 }finally{f.dom.window.close();}
});
