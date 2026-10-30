const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {stripTypeScriptTypes}=require('node:module');
async function fixture(name){
 const calls=[];let handler;
 const key='__deviceEdge'+crypto.randomUUID().replaceAll('-','');
 class ApiError extends Error{constructor(message,status=400){super(message);this.status=status;}}
 const me={id:'verified-user',sessionId:'verified-session',role:'student',status:'active'};
 const db={rpc:async(n,a)=>{calls.push([n,a]);if(n==='portal_start_on_device')return {data:{id:'attempt1'}};if(n==='attempt_payload')return {data:{exam:{shuffle:false},questions:[]}};if(n==='portal_submit_on_device')return {data:{body:{ok:true},status:200}};return {data:{ok:true}};},from:()=>({update:()=>({eq:async()=>({})})})};
 globalThis[key]={admin:()=>db,ApiError,json:(b,s=200,h={})=>new Response(JSON.stringify(b),{status:s,headers:h}),requireIdentity:async()=>{calls.push(['identity']);return me;},requireUser:async()=>{calls.push(['approved-user']);return me;},serve:f=>async req=>{try{return await f(req);}catch(e){return new Response(e.message,{status:e.status||400});}},sqlError:e=>new ApiError(e.message),clientIp:()=>null,Deno:{serve:f=>handler=f}};
 let source=fs.readFileSync(`supabase/functions/${name}/index.ts`,'utf8').replace(/^import .*;$/m,`const {admin,ApiError,json,requireIdentity,requireUser,serve,sqlError,clientIp,Deno}=globalThis.${key};`);
 await import('data:text/javascript;base64,'+Buffer.from(stripTypeScriptTypes(source)).toString('base64'));delete globalThis[key];
 return {calls,handler};
}
test('recovery verifies identity and ignores client-supplied actor/session fields',async()=>{const f=await fixture('portal-devices');const r=await f.handler(new Request('https://fixture/portal-devices',{method:'POST',body:JSON.stringify({action:'register',data:{token:'a'.repeat(64),p_user:'victim',p_session:'stolen'},p_user:'victim'})}));assert.equal(r.status,200);const rpc=f.calls.find(x=>x[0]==='portal_device_action');assert.equal(rpc[1].p_user,'verified-user');assert.equal(rpc[1].p_session,'verified-session');assert.equal(r.headers.get('Cache-Control'),'no-store');});
test('invalid recovery operations and oversized payloads are rejected before RPC',async()=>{const f=await fixture('portal-devices');for(const body of ['{',JSON.stringify({action:'delete',data:{}}),JSON.stringify({action:'list',data:[]}),JSON.stringify({action:'list',data:{text:'x'.repeat(8200)}})]){const r=await f.handler(new Request('https://fixture/portal-devices',{method:'POST',body}));assert.ok([400,413].includes(r.status));}assert.equal(f.calls.length,0);});
test('start and submit use the verified session and preserve server-side scoring paths',async()=>{const f=await fixture('start-attempt');const r=await f.handler(new Request('https://fixture/start',{method:'POST',body:JSON.stringify({exam_id:'exam1',session_id:'fake',transfer:true})}));assert.equal(r.status,201);assert.deepEqual(f.calls.find(x=>x[0]==='portal_start_on_device')[1],{p_exam:'exam1',p_user:'verified-user',p_session:'verified-session',p_untimed:false,p_transfer:true});const s=await fixture('submit-attempt');await s.handler(new Request('https://fixture/submit',{method:'POST',headers:{'Idempotency-Key':'key'},body:JSON.stringify({attempt_id:'attempt1',session_id:'fake'})}));assert.equal(s.calls.find(x=>x[0]==='portal_submit_on_device')[1].p_session,'verified-session');});
