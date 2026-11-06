const vm=require('node:vm');
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('fs');const {JSDOM}=require('./english-runtime/node_modules/jsdom');
function setup(error=null){const dom=new JSDOM(fs.readFileSync('web/study-plan.html','utf8'),{runScripts:'outside-only',url:'https://portal.test/study-plan.html'});const w=dom.window;w.eval=code=>vm.runInContext(code,dom.getInternalVMContext());let writes=[];w.supabase={createClient:()=>({from:table=>({upsert:row=>({select:async()=>{writes.push({table,row});return {data:[row],error}}})})})};w.eval(fs.readFileSync('web/study-plan.js','utf8').replace(/boot\(\);\s*$/,'')+`me={id:'one'};staff=false;$('date').value='2026-11-05';plans=[{user_id:'one',track_id:'sat',study_date:'2026-11-05',title:'<img src=x onerror=alert(1)>',instructions:'Review systems',lesson:'Systems',time_budget:'60 min',calculator_allowed:true,destination:'practice',practice_exam_id:'exam-one'}];progress=['lesson','practice','retest'].map(activity=>({user_id:'one',track_id:'sat',study_date:'2026-11-05',activity,status:activity==='practice'?'pending':'needs_link'}));render();`);return {w,writes};}
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
test('server completion evidence shows submitted time and read-only history',()=>{
 const {w}=setup();
 w.eval("progress[1].status='completed';progress[1].submitted_at='2026-11-05T10:30:00Z';render();");
 assert.match(w.document.querySelectorAll('.card')[1].textContent,/Completed automatically/);
 assert.match(w.document.querySelectorAll('.card')[1].textContent,/12:30/);
 w.eval("history=true;render();");
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
 const {w}=setup();w.eval("loading=true;plans=[];progress=[];$('content').replaceChildren();history=true;render();");assert.equal(w.document.getElementById('content').textContent,'');w.close();
});

test('failed planner refresh cannot enable editing with a stale roster',async()=>{
 const {w}=setup();w.eval("staff=true;sb.from=()=>({select(){return this},eq(){return this},order(){return this},range:async()=>({error:{message:'network failed'}})});");
 await w.load();assert.equal(w.document.getElementById('edit').disabled,true);assert.match(w.document.getElementById('message').textContent,/Could not load/);w.close();
});
test('confirmed objective write does not hide a subsequent refresh failure',async()=>{
 const {w}=setup();const form=w.document.getElementById('planForm');
 form.elements.title.value='Systems';form.elements.instructions.value='Review two methods';form.elements.time_budget.value='30 minutes';
 w.document.getElementById('editor').close=()=>{};
 w.eval("editorTarget={track:'sat',date:'2026-11-05',users:['one']};sb.from=()=>({upsert:row=>({select:async()=>({data:row})})});load=async()=>{message('Could not load the plan: network failed',true);return false;};");
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
