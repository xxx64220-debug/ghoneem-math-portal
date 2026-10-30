import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {PGlite} from './device-runtime/node_modules/@electric-sql/pglite/dist/index.js';

const uid='10000000-0000-4000-8000-000000000001', other='10000000-0000-4000-8000-000000000002', aid='20000000-0000-4000-8000-000000000001', eid='30000000-0000-4000-8000-000000000001';
const sid=n=>`40000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
async function fixture({legacy=false,listHotfix=false}={}){
 const db=new PGlite();
 await db.exec(`
 create role anon; create role authenticated; create role service_role bypassrls;
 create schema auth; create schema portal_private;
 grant usage on schema auth,portal_private to authenticated,service_role;
 create function auth.jwt() returns jsonb language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb $$;
 create function auth.uid() returns uuid language sql stable as $$ select nullif(auth.jwt()->>'sub','')::uuid $$;
 create table public.profiles(id uuid primary key,role text,status text,full_name text);
 create table auth.sessions(id uuid primary key,user_id uuid,created_at timestamptz default now(),not_after timestamptz);
 create table public.device_sessions(id uuid primary key default gen_random_uuid(),user_id uuid references profiles(id),device_hash text,session_id uuid,user_agent text default '',last_seen timestamptz default now(),revoked_at timestamptz,unique(user_id,device_hash));
 create unique index devices_session_unique on device_sessions(session_id) where session_id is not null;
 create table public.exams(id uuid primary key);
 create table public.attempts(id uuid primary key,user_id uuid,exam_id uuid,status text,deadline_at timestamptz);
 create table public.attempt_answers(attempt_id uuid references attempts(id),question_id uuid,response text,primary key(attempt_id,question_id));
 create table public.audit_log(actor_id uuid,action text,target_type text,target_id text,meta jsonb,at timestamptz default now());
 create function portal_private.attempt_course_access(uuid,uuid,boolean) returns boolean language sql as $$select true$$;
 create function public.portal_start_attempt(p_exam uuid,p_user uuid,p_untimed boolean) returns attempts language sql as $$select a from attempts a where user_id=p_user and exam_id=p_exam$$;
 create function public.portal_submit(p_attempt uuid,p_user uuid,p_key text) returns jsonb language sql as $$select jsonb_build_object('status',200,'body',jsonb_build_object('ok',true))$$;
 create function public.attempt_live_for(uuid,uuid) returns boolean language sql as $$select true$$;
 alter table profiles enable row level security;
 create policy own_profile on profiles to authenticated using(id=auth.uid());
 alter table attempts enable row level security;
 create policy own_attempt on attempts to authenticated using(user_id=auth.uid());
 alter table attempt_answers enable row level security;
 create policy answer_read on attempt_answers for select to authenticated using(exists(select 1 from attempts where id=attempt_id and user_id=auth.uid()));
 create policy answer_insert on attempt_answers for insert to authenticated with check(attempt_live_for(attempt_id,auth.uid()));
 create policy answer_update on attempt_answers for update to authenticated using(attempt_live_for(attempt_id,auth.uid())) with check(attempt_live_for(attempt_id,auth.uid()));
 grant select on profiles,attempts,attempt_answers to authenticated;
 grant insert,update on attempt_answers to authenticated;
 insert into profiles values('${uid}','student','active','Student'),('${other}','admin','active','Admin');
 insert into exams values('${eid}');
 insert into attempts values('${aid}','${uid}','${eid}','in_progress',now()+interval '1 hour');
 insert into auth.sessions(id,user_id) values('${sid(1)}','${uid}'),('${sid(2)}','${uid}'),('${sid(3)}','${uid}'),('${sid(4)}','${uid}'),('${sid(5)}','${other}');
 `);
 if(legacy)await db.exec(`insert into device_sessions(user_id,device_hash,session_id,user_agent) values('${uid}','${sid(1)}','${sid(1)}','Existing'),('${uid}','${sid(99)}','${sid(99)}','Stale');`);
 await db.exec(readFileSync('supabase/sql/device_access.sql','utf8'));
 await db.exec('set check_function_bodies = false');
 await db.exec(readFileSync('supabase/sql/device_access_rpc_guards.sql','utf8'));
 await db.exec('set check_function_bodies = true');
 if(listHotfix){
  const oldRelease=readFileSync('security-releases/20261030-device-access/apply.sql','utf8');
  const start=oldRelease.indexOf('create function public.portal_device_action(');
  const end=oldRelease.indexOf('create function portal_private.claim_exam(',start);
  assert.ok(start>=0&&end>start);
  await db.exec(oldRelease.slice(start,end).replace('create function public.portal_device_action(','create or replace function public.portal_device_action('));
  await db.exec(readFileSync('supabase/sql/device_access_list_fix.sql','utf8'));
  await assert.rejects(()=>db.exec(readFileSync('supabase/sql/device_access_list_fix.sql','utf8')),/device_list_fix_precondition_failed/);
 }
 const action=async(s,a,data={},user=uid)=>(await db.query('select portal_device_action($1,$2,$3,$4,$5) result',[user,s,a,JSON.stringify(data),'Test browser'])).rows[0].result;
 const reg=(s,t,user=uid)=>action(s,'register',{token:t.repeat(64),label:'Test browser'},user);
 const claim=(s,transfer=false)=>(db.query('select portal_private.claim_exam($1,$2,$3,$4)',[aid,uid,s,transfer]));
 const asUser=async(s,callback,user=uid)=>db.transaction(async tx=>{
  await tx.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify({sub:user,role:'authenticated',session_id:s})]);
  await tx.exec('set local role authenticated');return callback(tx);
 });
 return {db,action,reg,claim,asUser};
}

for(const listHotfix of [false,true])test(`device lists support approved and pending students plus scoped administrator review${listHotfix?' after the deployed-function fix':''}`,async()=>{
 const f=await fixture({listHotfix});try{
  const approved=await f.reg(sid(1),'a'),pending=await f.reg(sid(2),'b');
  const admin=await f.reg(sid(5),'c',other);
  for(const session of [sid(1),sid(2)]){
   const list=await f.action(session,'list');
   assert.equal(list.approved,session===sid(1));
   assert.deepEqual(new Set(list.devices.map(d=>d.id)),new Set([approved.browser_id,pending.browser_id]));
   assert.ok(list.devices.every(d=>d.user_id===uid));
   assert.ok(list.devices.every(d=>!('token_hash' in d)&&!('token' in d)&&!('session_id' in d)));
   await assert.rejects(()=>f.action(session,'list',{admin:true}),/admin_required/);
  }
  const own=await f.action(sid(5),'list',{},other);
  assert.deepEqual(own.devices.map(d=>d.id),[admin.browser_id]);
  const all=await f.action(sid(5),'list',{admin:true},other);
  assert.equal(all.devices.length,3);
  assert.deepEqual(new Set(all.devices.map(d=>d.user_id)),new Set([uid,other]));
  await f.db.query('insert into auth.sessions(id,user_id) values($1,$2)',[sid(6),other]);
  await f.reg(sid(6),'d',other);
  await assert.rejects(()=>f.action(sid(6),'list',{admin:true},other),/admin_required/);
 }finally{await f.db.close();}
});

test('trusted browser survives login changes; pending sessions cannot read or save answers',async()=>{
 const f=await fixture();try{
  const b=await f.reg(sid(1),'a'); assert.equal(b.status,'approved');
  const same=await f.reg(sid(2),'a');assert.equal(same.browser_id,b.browser_id);
  const pending=await f.reg(sid(3),'b');assert.equal(pending.status,'pending');
  assert.equal((await f.asUser(sid(3),tx=>tx.query('select * from attempts'))).rows.length,0);
  await assert.rejects(()=>f.asUser(sid(3),tx=>tx.query('select admin_bank_page(null,null,null,null,null,null,0,50)')),/device_approval_required/);
  await assert.rejects(()=>f.asUser(sid(3),tx=>tx.query('insert into attempt_answers values($1,$2,$3)',[aid,eid,'pending'])) ,/device_approval_required/);
  await f.asUser(sid(1),tx=>tx.query('insert into attempt_answers values($1,$2,$3)',[aid,eid,'A']));
  assert.equal((await f.db.query('select count(*)::int n from portal_private.attempt_devices')).rows[0].n,1);
  await f.action(sid(1),'approve',{id:pending.browser_id});
  assert.equal((await f.reg(sid(3),'b')).status,'approved');
  await assert.rejects(()=>f.claim(sid(3)),/exam_on_another_device/);
 }finally{await f.db.close();}
});

test('transfer preserves deadline and answers; old device cannot write or submit; cooldown applies',async()=>{
 const f=await fixture();try{
  await f.reg(sid(1),'a');const b=await f.reg(sid(2),'b');await f.action(sid(1),'approve',{id:b.browser_id});await f.reg(sid(2),'b');
  await f.asUser(sid(1),tx=>tx.query('insert into attempt_answers values($1,$2,$3)',[aid,eid,'A']));
  const before=(await f.db.query('select deadline_at from attempts')).rows[0].deadline_at;
  await f.claim(sid(2),true);
  await assert.rejects(()=>f.asUser(sid(1),tx=>tx.query('insert into attempt_answers values($1,$2,$3) on conflict(attempt_id,question_id) do update set response=excluded.response',[aid,eid,'B'])),/exam_on_another_device/);
  await assert.rejects(()=>f.db.query('select portal_submit_on_device($1,$2,$3,null)',[aid,uid,sid(1)]),/exam_on_another_device/);
  await f.asUser(sid(2),tx=>tx.query('insert into attempt_answers values($1,$2,$3) on conflict(attempt_id,question_id) do update set response=excluded.response',[aid,eid,'C']));
  assert.deepEqual((await f.db.query('select deadline_at from attempts')).rows[0].deadline_at,before);
  assert.equal((await f.db.query('select response from attempt_answers')).rows[0].response,'C');
  await assert.rejects(()=>f.claim(sid(1),true),/exam_transfer_cooldown/);
 }finally{await f.db.close();}
});

test('two-browser limit, verified replacement, own scope, reauthentication and revoked browser enforcement',async()=>{
 const f=await fixture();try{
  const a=await f.reg(sid(1),'a'),b=await f.reg(sid(2),'b');await f.action(sid(1),'approve',{id:b.browser_id});await f.reg(sid(2),'b');
  const c=await f.reg(sid(3),'c');await assert.rejects(()=>f.action(sid(1),'approve',{id:c.browser_id}),/device_limit_reached/);
  await f.action(sid(1),'approve',{id:c.browser_id,replace_id:b.browser_id});await f.reg(sid(3),'c');
  await assert.rejects(()=>f.reg(sid(4),'b'),/device_revoked/);
  const admin=await f.reg(sid(5),'d',other);await assert.rejects(()=>f.action(sid(1),'revoke',{id:admin.browser_id}),/device_not_found/);
  await assert.rejects(()=>f.action(sid(1),'limit',{user_id:uid,max_browsers:3}),/admin_required/);
  await f.db.query("update auth.sessions set created_at=now()-interval '1 hour' where id=$1",[sid(1)]);
  await assert.rejects(()=>f.action(sid(1),'revoke',{id:a.browser_id}),/reauthentication_required/);
  await f.action(sid(5),'revoke',{id:a.browser_id},other);
  await assert.rejects(()=>f.db.query('select portal_session($1,$2,$3)',[uid,sid(1),'agent']),/device_revoked/);
  assert.equal((await f.asUser(sid(1),tx=>tx.query('select * from profiles'))).rows.length,0);
 }finally{await f.db.close();}
});

test('missing/deleted/expired sessions and account suspension fail closed',async()=>{
 const f=await fixture();try{
  await f.reg(sid(1),'a');await f.claim(sid(1));
  assert.equal((await f.asUser(sid(99),tx=>tx.query('select attempt_live_for($1,$2) ok',[aid,uid]))).rows[0].ok,false);
  await f.db.query('update auth.sessions set not_after=now()-interval \'1 minute\' where id=$1',[sid(1)]);
  assert.equal((await f.asUser(sid(1),tx=>tx.query('select attempt_live_for($1,$2) ok',[aid,uid]))).rows[0].ok,false);
  await f.db.query('update auth.sessions set not_after=null where id=$1',[sid(1)]);
  await f.db.query("update profiles set status='suspended' where id=$1",[uid]);
  assert.equal((await f.asUser(sid(1),tx=>tx.query('select attempt_live_for($1,$2) ok',[aid,uid]))).rows[0].ok,false);
  await f.db.query("update profiles set status='active' where id=$1",[uid]);await f.db.query('delete from auth.sessions where id=$1',[sid(1)]);
  assert.equal((await f.asUser(sid(1),tx=>tx.query('select attempt_live_for($1,$2) ok',[aid,uid]))).rows[0].ok,false);
 }finally{await f.db.close();}
});

test('rollout preserves approved legacy sessions and excludes stale Auth records',async()=>{
 const f=await fixture({legacy:true});try{
  assert.equal((await f.db.query('select count(*)::int n from portal_private.trusted_browsers')).rows[0].n,1);
  await f.db.query('select portal_session($1,$2,$3)',[uid,sid(1),'Existing']);
  const before=(await f.db.query('select browser_id from device_sessions where session_id=$1',[sid(1)])).rows[0].browser_id;
  const known=await f.reg(sid(1),'a');assert.equal(known.browser_id,before);
  assert.equal((await f.reg(sid(2),'a')).browser_id,before);
  await assert.rejects(()=>f.db.query('select portal_session($1,$2,$3)',[uid,sid(99),'Stale']),/invalid_session/);
 }finally{await f.db.close();}
});

test('cannot replace a browser during its exam; service-only mutations deny direct calls',async()=>{
 const f=await fixture();try{
  const a=await f.reg(sid(1),'a');await f.claim(sid(1));const b=await f.reg(sid(2),'b');
  await assert.rejects(()=>f.action(sid(1),'approve',{id:b.browser_id,replace_id:a.browser_id}),/device_has_active_exam/);
  await assert.rejects(()=>f.asUser(sid(1),tx=>tx.query('select portal_device_action($1,$2,$3,$4,$5)',[uid,sid(1),'approve',JSON.stringify({id:b.browser_id}),'Fake'])),/permission denied/);
  const grants=await f.db.query("select has_function_privilege('authenticated','portal_start_on_device(uuid,uuid,uuid,boolean,boolean)','execute') allowed,has_function_privilege('anon','portal_device_action(uuid,uuid,text,jsonb,text)','execute') anonymous");
  assert.equal(grants.rows[0].allowed,false);assert.equal(grants.rows[0].anonymous,false);
 }finally{await f.db.close();}
});

test('stale authentication cannot transfer an exam and a different account cannot claim it',async()=>{
 const f=await fixture();try{
  await f.reg(sid(1),'a');const b=await f.reg(sid(2),'b');await f.action(sid(1),'approve',{id:b.browser_id});await f.reg(sid(2),'b');await f.claim(sid(1));
  await f.db.query("update auth.sessions set created_at=now()-interval '1 hour' where id=$1",[sid(2)]);
  await assert.rejects(()=>f.claim(sid(2),true),/reauthentication_required/);
  await f.reg(sid(5),'c',other);
  await assert.rejects(()=>f.db.query('select portal_private.claim_exam($1,$2,$3,false)',[aid,other,sid(5)]),/attempt_not_found/);
 }finally{await f.db.close();}
});
