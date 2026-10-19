const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {stripTypeScriptTypes} = require('node:module');
async function authFixture({user=true,role='student',status='active',session=true,revoked=false,profile=true}={}) {
  const calls=[];
  const token = 'e30.'+Buffer.from(JSON.stringify({role:'admin',user_metadata:{role:'admin'},...(session?{session_id:'00000000-0000-4000-8000-000000000001'}:{})})).toString('base64url')+'.signature';
  const key = '__authSecurityFixture'+crypto.randomUUID().replaceAll('-','');
  globalThis[key] = () => ({
    auth:{getUser:async()=>{calls.push('verify-user');return {data:{user:user?{id:'verified-user',user_metadata:{role:'admin'}}:null},error:user?null:{message:'bad signature'}};}},
    from:table=>({select(){return this;},eq(column,value){calls.push([table,column,value]);return this;},async single(){return {data:profile?{id:'verified-user',role,status}:null,error:null};}}),
    rpc:async(name,args)=>{calls.push([name,args]);return {error:revoked?{message:'session_revoked'}:null};}
  });
  const source = fs.readFileSync('supabase/functions/_shared/http.ts','utf8')
    .replace(/^import .*from .*;$/m,`const createClient = globalThis.${key};`)
    .replaceAll('Deno.env.get','(() => undefined)');
  const api = await import('data:text/javascript;base64,'+Buffer.from(stripTypeScriptTypes(source)).toString('base64'));
  delete globalThis[key];
  const req = new Request('https://fixture.invalid',{headers:{Authorization:'Bearer '+token}});
  return {api,req,calls};
}
test('missing and invalid JWTs are denied before profile/session access',async()=>{
  const f=await authFixture({user:false});
  await assert.rejects(()=>f.api.requireUser(new Request('https://fixture.invalid')),e=>e.status===401&&e.message==='missing_token');
  await assert.rejects(()=>f.api.requireUser(f.req),e=>e.status===401&&e.message==='invalid_token');
  assert.deepEqual(f.calls,['verify-user']);
});
test('verified user identity and active database role override editable JWT metadata',async()=>{
  const f=await authFixture();
  assert.equal((await f.api.requireUser(f.req)).role,'student');
  await assert.rejects(()=>f.api.requireStaff(f.req),e=>e.status===403);
  await assert.rejects(()=>f.api.requireAdmin(f.req),e=>e.status===403);
  assert(f.calls.some(x=>Array.isArray(x)&&x[0]==='profiles'&&x[2]==='verified-user'));
  assert(f.calls.some(x=>Array.isArray(x)&&x[0]==='portal_session'&&x[1].p_user==='verified-user'));
});
test('suspended, missing-profile, sessionless and revoked callers fail closed',async()=>{
  for(const [options,error] of [[{status:'suspended'},'account_suspended'],[{profile:false},'no_profile'],[{session:false},'invalid_session'],[{revoked:true},'session_revoked']]) {
    const f=await authFixture(options);await assert.rejects(()=>f.api.requireUser(f.req),e=>e.status>=401&&e.message===error);
  }
});
test('active instructors and admins keep their intended privileges',async()=>{
  const teacher=await authFixture({role:'instructor'}),admin=await authFixture({role:'admin'});
  assert.equal((await teacher.api.requireStaff(teacher.req)).role,'instructor');
  await assert.rejects(()=>teacher.api.requireAdmin(teacher.req),e=>e.status===403);
  assert.equal((await admin.api.requireAdmin(admin.req)).role,'admin');
});
