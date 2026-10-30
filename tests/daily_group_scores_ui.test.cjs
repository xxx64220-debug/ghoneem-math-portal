const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {JSDOM}=require('./english-runtime/node_modules/jsdom');
const a='00000000-0000-4000-8000-000000000001',b='00000000-0000-4000-8000-000000000002';
function state(group=a){return {track:'sat',group_id:group,scope_id:group,group_name:group===a?'Class A':'Class B',groups:[{id:a,name:'Class A'},{id:b,name:'Class B'}],date:'2026-10-15',reset_at:'2026-10-15T21:00:00Z',completed:false,score:null,points_total:group===a?90:0,points_today:0,rank:1,leaderboard:[{rank:1,name:'Student',points:group===a?90:0,completed:1}],checklist:{quiz:false,focus:false,review:false,bonus:false},streak:{current:group===a?1:0,longest:1,week:[]},quiz:Array.from({length:5},(_,i)=>({id:group+'-'+i,stem:'Synthetic question '+i,choices:['A','B','C','D'].map(key=>({key,text:key+' choice'})),answer:null}))};}
function setup(){const dom=new JSDOM('<main id="dashboardContent"></main>',{runScripts:'outside-only'}),c=dom.getInternalVMContext();c.setInterval=()=>{};Object.assign(c,{ST:{track:{id:'sat',theme:{label:'SAT'}}},DASH:{view:'daily',daily:state(),searchTerm:''},esc:s=>String(s??'').replace(/[&<>"]/g,x=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[x])),figure:()=>'',friendly:x=>x,console});c.calls=[];c.fn=async(name,opts)=>{c.calls.push({name,opts});return {ok:true,json:state(opts?.body?.group_id||b)}};c.paintDashboardContent=()=>{dom.window.document.getElementById('dashboardContent').innerHTML=c.dailyPanel();c.wireDaily()};c.paintDashboard=c.paintDashboardContent;vm.runInContext(fs.readFileSync('web/daily-challenge.js','utf8'),c);c.paintDashboardContent();return {c,dom};}
const flush=()=>new Promise(r=>setImmediate(r));
test('group selector labels the leaderboard and switches without carrying answers or points',async()=>{
 const {c,dom}=setup();assert.match(c.dailyPanel(),/Class A leaderboard/);assert.match(c.dailyPanel(),/Each assigned group has its own streak/);
 vm.runInContext("DAILY_DRAFT['old-question']='A'",c);
 const selector=dom.window.document.getElementById('dailyGroup');selector.value=b;selector.dispatchEvent(new dom.window.Event('change'));await flush();
 assert.match(c.calls.at(-1).opts.qs,/group_id=00000000-0000-4000-8000-000000000002/);assert.equal(c.DASH.daily.scope_id,b);assert.equal(c.DASH.daily.points_total,0);assert.equal(vm.runInContext('Object.keys(DAILY_DRAFT).length',c),0);
 assert.match(c.dailyPanel(),/Class B leaderboard/);
});
test('submission binds the selected group and date; selector cannot switch while saving',async()=>{
 const {c,dom}=setup();let finish;c.fn=async(name,opts)=>{c.calls.push({name,opts});return new Promise(r=>finish=r)};
 for(const q of c.DASH.daily.quiz)vm.runInContext(`DAILY_DRAFT[${JSON.stringify(q.id)}]='A'`,c);
 dom.window.document.querySelector('[data-daily-submit]').click();
 const sent=c.calls.at(-1).opts.body;assert.equal(sent.group_id,a);assert.equal(sent.day,'2026-10-15');assert.equal(Object.keys(sent.answers).length,5);assert.equal(dom.window.document.getElementById('dailyGroup').disabled,true);
 finish({ok:true,json:{...state(a),completed:true,score:5}});await flush();assert.equal(c.DASH.daily.scope_id,a);assert.equal(c.DASH.daily.score,5);
});
test('out-of-order group reads and old-track submissions cannot replace current data',async()=>{
 const {c,dom}=setup(),pending=[];c.fn=(name,opts)=>new Promise(resolve=>pending.push({resolve,opts}));
 const pa=c.refreshDaily(a),pb=c.refreshDaily(b);pending[1].resolve({ok:true,json:state(b)});await pb;pending[0].resolve({ok:true,json:state(a)});await pa;assert.equal(c.DASH.daily.scope_id,b);
 for(const q of c.DASH.daily.quiz)vm.runInContext(`DAILY_DRAFT[${JSON.stringify(q.id)}]='A'`,c);c.paintDashboardContent();dom.window.document.querySelector('[data-daily-submit]').click();
 c.ST.track={id:'est'};c.DASH.daily={...state(),track:'est'};pending[2].resolve({ok:true,json:{...state(b),completed:true}});await flush();assert.equal(c.DASH.daily.track,'est');assert.equal(c.DASH.daily.completed,false);
});
test('mark checklist sends only the current group and failure keeps its results',async()=>{
 const {c,dom}=setup();c.fn=async(name,opts)=>{c.calls.push({name,opts});return {ok:false,json:{error:'temporary'}}};dom.window.document.querySelector('[data-daily-mark="focus"]').click();await flush();assert.equal(c.calls.at(-1).opts.body.group_id,a);assert.equal(c.DASH.daily.points_total,90);assert.match(dom.window.document.getElementById('daily-message').textContent,/temporary/);
});
test('group metadata is escaped and no quiz keys are exposed before completion',()=>{const {c}=setup();c.DASH.daily={...state(),group_name:'<script>bad</script>',groups:[{id:a,name:'<script>bad</script>'}]};assert.doesNotMatch(c.dailyPanel(),/<script>/);assert.match(c.dailyPanel(),/&lt;script&gt;/);assert.doesNotMatch(c.dailyPanel(),/Correct answer:/)});
