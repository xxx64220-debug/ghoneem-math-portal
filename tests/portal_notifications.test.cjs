const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const sw=fs.readFileSync('web/portal-sw.js','utf8');
const {stripTypeScriptTypes}=require('node:module');
const edge=fs.readFileSync('supabase/functions/portal-notifications/index.ts','utf8');
test('queued reminders and announcements recheck effective course access',async()=>{
 const calls=[];let permitted=new Set(['sat']);let rows=[{track_id:'est'},{track_id:'sat'}];
 const query={select(){return this},eq(k,v){calls.push([k,v]);return this},then(resolve){return Promise.resolve({data:rows}).then(resolve)}};
 const context={db:{from:()=>query,rpc:async(name,args)=>{calls.push([name,args]);return {data:permitted.has(args.p_track)}}},check:r=>{if(r.error)throw Error(r.error);return r.data}};
 vm.createContext(context);vm.runInContext(stripTypeScriptTypes(edge.slice(edge.indexOf('async function hasCurrentCourseAccess'),edge.indexOf('async function work'))),context);
 assert.equal(await context.hasCurrentCourseAccess('student'),true);
 assert.deepEqual(calls.filter(c=>c[0]==='is_enrolled').map(c=>c[1].p_track),['est','sat']);
 permitted=new Set();assert.equal(await context.hasCurrentCourseAccess('student'),false);
 rows=[];assert.equal(await context.hasCurrentCourseAccess('student','est'),false);assert.ok(calls.some(c=>c[0]==='track_id'&&c[1]==='est'));
 assert.match(edge,/reminders&&await hasCurrentCourseAccess\(s.user_id\)/);
 assert.match(edge,/await hasCurrentCourseAccess\(s.user_id,c.track_id\)/);
});
function setup(tabs=[]){const handlers={},shown=[],opened=[];const self={location:{origin:'https://math.portal.ghoneem.com'},addEventListener:(n,f)=>handlers[n]=f,registration:{showNotification:async(t,o)=>shown.push({t,o})},clients:{matchAll:async()=>tabs,openWindow:async(u)=>opened.push(u)}};vm.runInNewContext(sw,{self,URL,Response,fetch:async()=>{throw Error('offline');}});return {handlers,shown,opened};}
test('push uses plain text and fixed safe navigation, never server supplied URL',async()=>{const s=setup();let wait;s.handlers.push({data:{json:()=>({title:'Test',body:'Hi',url:'https://evil.example'})},waitUntil:p=>wait=p});await wait;assert.equal(s.shown[0].o.data.url,'/');});
test('notification click focuses ongoing exam without navigation',async()=>{let focused=false;const s=setup([{url:'https://math.portal.ghoneem.com/?exam=123',focus:async()=>{focused=true;}}]);let wait;s.handlers.notificationclick({notification:{close(){}},waitUntil:p=>wait=p});await wait;assert.ok(focused);assert.equal(s.opened.length,0);});
test('closed portal opens home on tap',async()=>{const s=setup();let wait;s.handlers.notificationclick({notification:{close(){}},waitUntil:p=>wait=p});await wait;assert.deepEqual(s.opened,['/']);});
test('exam API calls and submissions bypass service worker',()=>{const s=setup();for(const r of [{method:'POST',mode:'navigate',url:'https://math.portal.ghoneem.com/'},{method:'GET',mode:'cors',url:'https://wfhurjyouemahvkcfkdz.supabase.co/rest/v1/attempts'}])s.handlers.fetch({request:r,respondWith:()=>assert.fail('API intercepted')});});
test('offline navigation returns connection guidance',async()=>{const s=setup();let p;s.handlers.fetch({request:{method:'GET',mode:'navigate',url:'https://math.portal.ghoneem.com/'},respondWith:r=>p=r});assert.equal((await p).status,503);});

async function runWorker({statusCode,attempts=1,subscription={},kind='test',profile='active',access=true,missingSubscription=false}={}){
 const writes=[],sends=[],calls=[];
 const sub={id:'device',user_id:'user',endpoint:'https://fcm.googleapis.com/fcm/send/isolated',origin:'https://math.portal.ghoneem.com',exams:true,results:true,reminders:true,p256dh:'key',auth:'auth',...subscription};
 const job={id:'job',subscription_id:sub.id,event_key:'test:isolated',kind,title:'Test',body:'Test',attempts};
 const db={rpc:async(name,args)=>{calls.push({name,args});return {data:name==='portal_push_claim'?[job]:['is_enrolled','student_assignment_for'].includes(name)?access:null};},from(table){
  const filters=[];
  const q={select(){return this},eq(k,v){filters.push([k,v]);return this},maybeSingle:async()=>({data:table==='profiles'?(profile?{status:profile}:null):missingSubscription?null:sub}),
   single:async()=>({data:{track_id:'sat'}}),
   update(value){writes.push({table,value,filters});return this},delete(){writes.push({table,deleted:true,filters});return this},
   then(resolve,reject){return Promise.resolve({data:table==='enrollments'?[{track_id:'sat'}]:null}).then(resolve,reject)}};return q;
 }};
 const context={db,check:r=>{if(r.error)throw r.error;return r.data},URL,
  webpush:{sendNotification:async(...args)=>{sends.push(args);if(statusCode)throw {statusCode};return {statusCode:201}}}};
 vm.createContext(context);
 vm.runInContext(stripTypeScriptTypes(fs.readFileSync('supabase/functions/portal-notifications/policy.ts','utf8').replace(/export /g,'')),context);
 vm.runInContext(stripTypeScriptTypes(edge.slice(edge.indexOf('async function hasCurrentCourseAccess'),edge.indexOf('Deno.serve'))),context);
 const result=await context.work({public_key:'public',private_key:'private'});
 return {writes,sends,result,calls};
}
test('provider acceptance is recorded after sending only the claimed device',async()=>{
 const r=await runWorker();assert.equal(r.sends.length,1);assert.equal(r.result.sent,1);
 assert.equal(r.sends[0][0].endpoint,'https://fcm.googleapis.com/fcm/send/isolated');
 assert.equal(r.writes[0].value.status,'sent');assert.ok(r.writes[0].value.sent_at);
 assert.deepEqual(r.writes[0].filters,[['id','job']]);
});
test('transient provider errors back off five minutes and stop after third attempt',async()=>{
 for(const attempts of [1,2,3]){
  const before=Date.now(),r=await runWorker({statusCode:503,attempts}),v=r.writes[0].value;
  assert.equal(r.result.sent,0);assert.equal(v.status,attempts===3?'failed':'pending');
  assert.equal(v.error,'push_delivery_failed');assert.ok(Date.parse(v.next_attempt)>=before+300000);
 }
});
test('404 and 410 remove only the expired subscription',async()=>{
 for(const statusCode of [404,410]){const r=await runWorker({statusCode});assert.equal(r.result.sent,0);assert.equal(r.writes.length,1);assert.equal(r.writes[0].table,'portal_push_subscriptions');assert.equal(r.writes[0].deleted,true);assert.deepEqual(r.writes[0].filters,[['id','device']]);}
});
test('queued jobs recheck disabled preferences, inactive accounts and endpoints',async()=>{
 for(const args of [{kind:'result',subscription:{results:false}},{kind:'exam',subscription:{exams:false}},{kind:'exam',access:false},{kind:'reminder',subscription:{reminders:false}},{kind:'reminder',subscription:{reminders:true},access:false},{kind:'announcement',access:false},{profile:'suspended'},{profile:null},{subscription:{origin:'https://evil.example'}},{subscription:{endpoint:'https://evil.example/push'}}]){
  const r=await runWorker(args);assert.equal(r.sends.length,0);assert.equal(r.writes[0].value.status,'skipped');
 }
});
test('an unsubscribed queued device is not sent or recreated',async()=>{
 const r=await runWorker({missingSubscription:true});assert.equal(r.sends.length,0);assert.equal(r.writes.length,0);
});
test('subscription policy rejects unsafe endpoints and malformed keys',()=>{
 const policy=fs.readFileSync('supabase/functions/portal-notifications/policy.ts','utf8');const context={URL};
 vm.createContext(context);vm.runInContext(stripTypeScriptTypes(policy.replace(/export /g,'')),context);
 for(const endpoint of ['http://fcm.googleapis.com/test','https://fcm.googleapis.com.evil.example/test','https://user:pass@fcm.googleapis.com/test','https://fcm.googleapis.com:8443/test','https://fcm.googleapis.com/test#fragment'])assert.equal(context.validEndpoint(endpoint),false);
 for(const endpoint of ['https://fcm.googleapis.com/test','https://updates.push.services.mozilla.com/test','https://web.push.apple.com/test'])assert.equal(context.validEndpoint(endpoint),true);
 assert.equal(context.validKeys({p256dh:'A'.repeat(87),auth:'A'.repeat(22)}),true);
 assert.equal(context.validKeys({p256dh:'short',auth:'short'}),false);
});

// Run the actual request router with synthetic DB/auth/provider boundaries.
// The shared requireUser implementation is separately exercised by auth_security.test.cjs.
async function notificationRequest(body,{worker,user,origin='https://math.portal.ghoneem.com',owner='student'}={}){
 const writes=[],calls=[];let handler;
 const db={rpc:async name=>{calls.push(name);return {data:name==='portal_push_claim'?[]:null};},from(table){
  const filters=[];let values;
  const result=()=>({data:table==='portal_push_config'?{public_key:'public',private_key:'private',worker_secret:'isolated-secret'}:
   table==='portal_push_subscriptions'?{id:'device',user_id:owner,exams:false,results:true,reminders:true}:null});
  return {select(){return this},eq(k,v){filters.push([k,v]);return this},single:async()=>result(),maybeSingle:async()=>result(),
   update(value){values=value;writes.push({table,values,filters});return this},
   delete(){writes.push({table,deleted:true,filters});return this},
   then(resolve,reject){return Promise.resolve(result()).then(resolve,reject)}};
 }};
 class ApiError extends Error{constructor(message,status=400){super(message);this.status=status;}}
 const context={URL,crypto,TextEncoder,admin:()=>db,ApiError,serve:f=>f,
  json:body=>body,requireUser:async()=>{if(!user)throw new ApiError('missing_token',401);return {id:user,role:'student'};},
  webpush:{generateRequestDetails:()=>{calls.push('encryption-check');return {body:'mock encrypted'};},sendNotification:()=>assert.fail('unexpected provider call')},
  Deno:{serve:f=>handler=f}};
 vm.createContext(context);
 vm.runInContext(stripTypeScriptTypes(fs.readFileSync('supabase/functions/portal-notifications/policy.ts','utf8').replace(/export /g,'')),context);
 vm.runInContext(stripTypeScriptTypes(edge.replace(/^import .*;\n/gm,'')),context);
 const headers={'content-type':'application/json'};
 if(worker!==undefined)headers['x-portal-worker']=worker;
 if(origin!==null)headers.origin=origin;
 const result=await handler(new Request('https://fixture.invalid',{method:'POST',headers,body:JSON.stringify(body)}));
 return {result,writes,calls};
}
test('dispatch and worker-check reject missing or wrong worker credentials before work',async()=>{
 for(const action of ['dispatch','worker-check'])for(const worker of [undefined,'','wrong','isolated-secret-extra']){
  await assert.rejects(()=>notificationRequest({action},{worker,user:'student'}),e=>e.status===403&&e.message==='forbidden');
 }
});
test('the scheduler uses its worker credential without a browser origin or user session',async()=>{
 const check=await notificationRequest({action:'worker-check'},{worker:'isolated-secret',origin:null});
 assert.equal(check.result.encryption_ready,true);assert.deepEqual(check.calls,['encryption-check']);
 const dispatch=await notificationRequest({action:'dispatch'},{worker:'isolated-secret',origin:null});
 assert.equal(dispatch.result.processed,0);assert.deepEqual(dispatch.calls,['portal_push_collect','portal_push_claim']);
});
test('worker credentials do not authorize user actions; user actions require an allowed origin',async()=>{
 await assert.rejects(()=>notificationRequest({action:'test'},{worker:'isolated-secret'}),e=>e.status===401);
 await assert.rejects(()=>notificationRequest({action:'status'},{user:'student',origin:'https://evil.example'}),e=>e.status===403&&e.message==='invalid_origin');
 const r=await notificationRequest({action:'config'},{user:'student'});
 assert.deepEqual(Object.keys(r.result),['publicKey']);assert.equal(r.result.publicKey,'public');
});
test('subscription updates and opt-out are scoped to the authenticated owner and endpoint',async()=>{
 const endpoint='https://fcm.googleapis.com/fcm/send/isolated';
 const body={action:'subscribe',subscription:{endpoint,keys:{p256dh:'A'.repeat(87),auth:'A'.repeat(22)}},preferences:{exams:false,results:true,reminders:true}};
 await assert.rejects(()=>notificationRequest(body,{user:'student',owner:'other-student'}),e=>e.status===409);
 const subscribed=await notificationRequest(body,{user:'student'});
 const updated=subscribed.writes[0];assert.equal(updated.values.exams,false);assert.equal(updated.values.results,true);assert.equal(updated.values.reminders,true);
 assert.deepEqual(updated.filters,[['endpoint',endpoint],['user_id','student']]);
 const unsubscribed=await notificationRequest({action:'unsubscribe',endpoint},{user:'student'});
 assert.deepEqual(unsubscribed.writes[0].filters,[['endpoint',endpoint],['user_id','student']]);assert.equal(unsubscribed.writes[0].deleted,true);
});
test('the scheduler SQL keeps one-minute dispatch and reads its credential from private storage',()=>{
 const schedule=fs.readFileSync('supabase/sql/portal_notification_schedule.sql','utf8');
 assert.match(schedule,/cron.schedule\('portal-push-delivery','\* \* \* \* \*'/);
 assert.match(schedule,/'x-portal-worker',\(select worker_secret from public.portal_push_config where id\)/);
 assert.match(schedule,/body:='\{"action":"dispatch"\}'::jsonb/);
 assert.doesNotMatch(schedule,/Bearer |service_role|sb_secret_/);
});
