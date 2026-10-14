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
