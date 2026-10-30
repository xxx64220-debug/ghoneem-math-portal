import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {PGlite} from './device-runtime/node_modules/@electric-sql/pglite/dist/index.js';
const root='security-releases/20261030-portal-followup/';
const read=p=>readFileSync(p,'utf8');
const functions=JSON.parse(read(root+'security-functions-before.json'));
const id=n=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const apis=['admin_bank_page','act2_collection_search','staff_diagnosis','staff_group_exam_evidence'];
test('private implementations preserve policy OIDs, role scope, session gates and service calls',async()=>{
 const db=new PGlite();
 try{
  await db.exec(`create role anon;create role authenticated;create role service_role;
   create schema auth;create schema portal_private;
   grant usage on schema auth,portal_private to authenticated,service_role;
   create function auth.jwt() returns jsonb language sql stable as $$select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb$$;
   create function auth.uid() returns uuid language sql stable as $$select nullif(auth.jwt()->>'sub','')::uuid$$;
   create function portal_private.current_session_allowed() returns boolean language sql stable as $$select coalesce((auth.jwt()->>'approved')::boolean,false)$$;
   create function portal_private.require_current_session() returns boolean language plpgsql as $$begin if not portal_private.current_session_allowed() then raise exception 'device_approval_required';end if;return true;end$$;
   create function public.course_history_access(uuid,text) returns boolean language sql as $$select true$$;
   create function portal_private.attempt_course_access(uuid,uuid,boolean) returns boolean language sql as $$select true$$;
   create table portal_private.attempt_devices(attempt_id uuid,user_id uuid,session_id uuid);
   create table public.act2_collection_documents(id uuid,filename text,category text,subject text,notes text,page_count int,size_bytes bigint,page_text jsonb);
  `);
  await db.exec(read(root+'security-fixture-tables.sql'));
  await db.exec(`create function public.jwt_role() returns text language sql stable security definer as $$select role from profiles where id=auth.uid() and status='active'$$;set check_function_bodies=false;`);
  for(const f of functions)await db.exec(f.definition);
  await db.exec('set check_function_bodies=true');
  await db.exec(`insert into profiles(id,role,status) values('${id(1)}','student','active'),('${id(2)}','student','active'),('${id(3)}','instructor','active'),('${id(4)}','instructor','active'),('${id(5)}','admin','active');
   insert into tracks(id,is_active) values('est',true),('sat',true);
   insert into enrollments(user_id,track_id,status) values('${id(1)}','est','active'),('${id(2)}','est','active');
   insert into instructor_tracks(user_id,track_id) values('${id(3)}','est'),('${id(4)}','est');
   insert into groups(id,track_id,instructor_id) values('${id(10)}','est','${id(3)}'),('${id(11)}','est','${id(4)}');
   insert into group_members(group_id,user_id) values('${id(10)}','${id(1)}'),('${id(11)}','${id(2)}');
   create table protected_rows(user_id uuid,value text);insert into protected_rows values('${id(1)}','own'),('${id(2)}','other');
   alter table protected_rows enable row level security;
   create policy scope on protected_rows to authenticated using(user_id=auth.uid() or public.staff_can_read_student(user_id));
   grant select on protected_rows to authenticated;
  `);
  const oids=(await db.query("select oid,proname from pg_proc where pronamespace='public'::regnamespace and proname=any($1)",[functions.map(f=>f.proname)])).rows;
  await db.exec(read('supabase/sql/private_policy_functions.sql'));
  const asUser=(user,approved,fn)=>db.transaction(async tx=>{
   await tx.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify({sub:user,approved,role:'authenticated'})]);
   await tx.exec('set local role authenticated');return fn(tx);
  });
  for(const f of functions){
   const r=(await db.query(`select p.oid,p.prosecdef,has_function_privilege('anon',p.oid,'EXECUTE') anon,has_function_privilege('authenticated',p.oid,'EXECUTE') authenticated,has_function_privilege('service_role',p.oid,'EXECUTE') service from pg_proc p where p.oid=$1::regprocedure`,['public.'+f.signature])).rows[0];
   assert.equal(r.prosecdef,false);assert.equal(r.anon,false);assert.equal(r.authenticated,apis.includes(f.proname));assert.equal(r.service,true);
   const moved=(await db.query('select $1::regprocedure::oid oid',['portal_private.'+f.signature])).rows[0];
   assert.equal(moved.oid,oids.find(x=>x.proname===f.proname).oid,'RLS dependency OID retained');
  }
  for(const [u,expected] of [[1,['own']],[3,['own']],[4,['other']],[5,['other','own']]]){
   const r=await asUser(id(u),true,tx=>tx.query('select value from protected_rows order by value'));assert.deepEqual(r.rows.map(x=>x.value),expected);
  }
  await assert.rejects(()=>asUser(id(1),true,tx=>tx.query('select public.is_enrolled($1,$2)',[id(2),'est'])),/permission denied/);
  const calls=["select admin_bank_page('est')","select act2_collection_search()","select staff_diagnosis('est')",`select staff_group_exam_evidence('${id(20)}','{}')`];
  for(const call of calls){
   await assert.rejects(()=>asUser(id(5),false,tx=>tx.query(call)),/device_approval_required/);
   await assert.rejects(()=>asUser(id(1),true,tx=>tx.query(call)),/forbidden|staff_required/);
  }
  await assert.rejects(()=>asUser(id(3),true,tx=>tx.query("select admin_bank_page('sat')")),/forbidden_track/);
  assert.deepEqual((await asUser(id(5),true,tx=>tx.query('select act2_collection_search() data'))).rows[0].data,[]);
  await db.transaction(async tx=>{await tx.exec('set local role service_role');assert.equal((await tx.query('select public.is_enrolled($1,$2) ok',[id(1),'est'])).rows[0].ok,true);});
 }finally{await db.close();}
});
