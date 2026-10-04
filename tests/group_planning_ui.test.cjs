const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const {JSDOM}=require('./english-runtime/node_modules/jsdom');
const source=fs.readFileSync('web/hardest-questions.js','utf8');
const roster='abcdefg'.split('').map(user_id=>({user_id,role:'student',full_name:'Student '+user_id,tracks:'est'}));
const lessons=['Circles','Linear equations','Statistics'].flatMap((lesson,i)=>['abcdef'[2*i],'abcdef'[2*i+1]].flatMap(user_id=>[
 {user_id,lesson,questions_seen:3,percent:20+i*10},{user_id,lesson:'Functions',questions_seen:3,percent:90}
]));
async function report({failure=false,visible=true,ready=true,delay=null}={}){
 const dom=new JSDOM('<nav class="tabs"><div class="wrap"></div></nav><div id="view"></div>',{runScripts:'outside-only',url:'http://localhost/'});
 const w=dom.window,reads=[],actions=[];
 w.ST={view:'finalsDiagnosisAdmin'};w.render=()=>{};w.syncAdminNavigation=()=>{};w.csv=()=>{};
 const fixtures={roster,student_by_lesson:lessons,results_feed:[],groups:[{id:'seven',name:'Seven',track_id:'est'}],group_members:roster.map(x=>({group_id:'seven',user_id:x.user_id})),exams:[{id:'retest',title:'EST I Final Weakness Retest — Oct 2026',is_published:true,track_id:'est',question_ids:Array(25).fill('q'),duration_seconds:2100}]};
 w.q=table=>{let bounds=[0,499];const query={eq:()=>query,order:()=>query,range:(a,b)=>{bounds=[a,b];return query;},then:async resolve=>{
   reads.push(table);if(delay&&table==='groups')await delay;
   return resolve(failure&&['groups','group_members','exams'].includes(table)?{error:new Error('Offline')}:{data:(fixtures[table]||[]).slice(bounds[0],bounds[1]+1)});
 }};return query;};
 w.portalControl=async(action,data)=>{actions.push({action,data});if(failure)throw new Error('Offline');return {visible,items:['Circles','Linear equations','Statistics'].map(lesson=>({lesson,active:true,ready}))};};
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
