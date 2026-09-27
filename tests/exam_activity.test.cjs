const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),{test}=require('node:test');
function setup(type='full_exam'){
 const listeners={},storage=new Map(),notice={},calls=[];
 const run={exam:{id:'exam1'},attempt:{id:'attempt1',deadline_at:new Date(Date.now()+600000).toISOString()}};
 const c={console,Set,Date,crypto:require('node:crypto').webcrypto,ST:{skew:0,run},DASH:{exams:[{id:'exam1',assessment_type:type}]},document:{visibilityState:'visible',getElementById:()=>notice,addEventListener:(name,fn)=>listeners[name]=fn},window:{addEventListener:(name,fn)=>listeners[name]=fn},sessionStorage:{getItem:k=>storage.get(k),setItem:(k,v)=>storage.set(k,v)},setInterval(){},async fn(name,options){calls.push({name,options});return {ok:true,json:{accepted:options.body.data.events.map(e=>e.id)}}}};
 vm.createContext(c);vm.runInContext(fs.readFileSync('web/exam-activity.js','utf8'),c);return {c,run,listeners,notice,calls,storage};
}
const settle=()=>new Promise(r=>setImmediate(r));
test('timed exams disclose tracking and log visibility changes once, without window-blur monitoring',async()=>{
 const {c,run,listeners,notice,calls}=setup();c.startExamActivity(run);await settle();assert.equal(notice.hidden,false);assert.match(notice.textContent,/does not automatically affect your score/);assert.equal(listeners.blur,undefined);
 c.document.visibilityState='hidden';listeners.visibilitychange();listeners.visibilitychange();await settle();c.document.visibilityState='visible';listeners.visibilitychange();await settle();
 assert.deepEqual(calls.flatMap(x=>x.options.body.data.events.map(e=>e.kind)),['started','hidden','visible']);c.stopExamActivity();c.document.visibilityState='hidden';listeners.visibilitychange();await settle();assert.equal(calls.length,3);
});
test('lesson and untimed practice do not emit activity',async()=>{
 const {c,run,notice,calls}=setup('lesson_exam');c.startExamActivity(run);await settle();assert.equal(notice.hidden,true);assert.equal(calls.length,0);c.DASH.exams[0].assessment_type='full_exam';run.attempt.deadline_at='infinity';c.startExamActivity(run);await settle();assert.equal(calls.length,0);
});
test('failed sends retain the same event IDs and retry after reconnect',async()=>{
 const {c,run,storage}=setup();let first;c.fn=async(name,opts)=>{first=opts.body.data.events;throw Error('offline')};c.startExamActivity(run);await settle();assert.equal(JSON.parse(storage.get('exam-activity:attempt1')).length,1);
 const id=first[0].id;c.fn=async(name,opts)=>{assert.equal(opts.body.data.events[0].id,id);return {ok:true,json:{accepted:[id]}}};await c.flushExamActivity();assert.equal(JSON.parse(storage.get('exam-activity:attempt1')).length,0);
});
test('completed or expired activity never adds departures',async()=>{
 const {c,run,listeners,calls}=setup();c.startExamActivity(run);await settle();vm.runInContext('EXAM_ACTIVITY.deadline=Date.now()-1',c);c.document.visibilityState='hidden';listeners.visibilitychange();await settle();assert.equal(calls.length,1);
});
