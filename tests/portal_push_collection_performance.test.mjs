import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {PGlite} from './device-runtime/node_modules/@electric-sql/pglite/dist/index.js';

// Disposable local PostgreSQL only. No real accounts, endpoints or network calls.
const read=p=>readFileSync(p,'utf8');
const captured=JSON.parse(read('performance-releases/20261110-disk-io/functions-before.json'));
const before=captured.find(x=>x.name==='portal_push_collect').definition;
const migration=read('supabase/migrations/20261110164655_optimize_portal_push_collection.sql');
const id=n=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;

test('collector preserves notification eligibility, idempotency, expiry and service-only access',async()=>{
 const db=new PGlite();
 try {
  await db.exec(`
   create role anon; create role authenticated; create role service_role bypassrls;
   create schema auth; create schema portal_private;
   create table auth.users(id uuid primary key,email text);
   create table profiles(id uuid primary key,role text,status text);
   create table tracks(id text primary key,is_active boolean);
   create table enrollments(user_id uuid,track_id text,status text,starts_at timestamptz,ends_at timestamptz,primary key(user_id,track_id));
   create table group_members(group_id uuid,user_id uuid,primary key(group_id,user_id));
   create table exams(id uuid primary key,track_id text,title text,is_published boolean);
   create table assignments(id uuid primary key,exam_id uuid,group_id uuid,user_id uuid,open_at timestamptz,close_at timestamptz,created_at timestamptz default now());
   create table attempts(id uuid primary key,user_id uuid,exam_id uuid,status text,submitted_at timestamptz,review_unlocks_at timestamptz);
   create function portal_private.is_enrolled(p_user uuid,p_track text) returns boolean language sql stable security definer set search_path=public,pg_temp as $$
    select exists(select 1 from public.enrollments e join public.profiles p on p.id=e.user_id join public.tracks t on t.id=e.track_id
    where e.user_id=p_user and e.track_id=p_track and e.status='active' and p.status='active' and p.role='student' and t.is_active
    and (e.starts_at is null or e.starts_at<=now()) and (e.ends_at is null or now()<e.ends_at)); $$;
   insert into tracks values('sat',true),('est',true),('inactive',false);
  `);
  for(const name of ['is_enrolled','student_assignment_for'])await db.exec(captured.find(x=>x.name===name).definition);
  await db.exec(read('supabase/sql/portal_notifications.sql'));
  const fresh=(await db.query("select pg_get_functiondef('public.portal_push_collect()'::regprocedure) d")).rows[0].d;
  await db.exec(before);
  // The guarded upgrade must work on the exact inspected definition.
  await db.exec(migration);
  assert.equal((await db.query("select pg_get_functiondef('public.portal_push_collect()'::regprocedure) d")).rows[0].d,fresh);
  await db.exec(read('performance-releases/20261110-disk-io/rollback.sql'));
  assert.equal((await db.query("select pg_get_functiondef('public.portal_push_collect()'::regprocedure) d")).rows[0].d,before);
  await db.exec(migration);
  await assert.rejects(()=>db.exec(migration),/Collector changed since inspection/);
  await db.exec(before.replace('public.portal_push_collect()','public.portal_push_collect_before()'));
  // Freeze now() for exact inclusive/exclusive access-window boundaries.
  await db.exec('begin');
  for(let u=1;u<=8;u++){
   await db.query('insert into profiles values($1,$2,$3)',[id(u),u===4?'instructor':'student',u===3?'suspended':'active']);
   await db.query("insert into enrollments values($1,'sat',$2,null,null)",[id(u),u===5?'paused':'active']);
   await db.query(`insert into portal_push_subscriptions(id,user_id,endpoint,p256dh,auth,origin,exams,results,reminders,created_at)
    values($1,$2,$3,'synthetic','synthetic','https://example.test',$4,$4,false,now()-interval '1 day')`,[id(100+u),id(u),'https://example.test/'+u,u!==6]);
  }
  await db.exec(`
   update enrollments set ends_at=now() where user_id='${id(2)}';
   update enrollments set starts_at=now()+interval '1 day' where user_id='${id(7)}';
   insert into group_members values('${id(20)}','${id(1)}'),('${id(21)}','${id(8)}');
   insert into portal_push_subscriptions(id,user_id,endpoint,p256dh,auth,origin,created_at)
    values('${id(109)}','${id(1)}','https://example.test/second','synthetic','synthetic','https://example.test',now()-interval '1 day');
  `);
  // Old/new releases, unassigned, direct/group overlap, windows and attempts.
  for(let n=1;n<=20;n++){
   await db.query('insert into exams values($1,$2,$3,$4)',[id(200+n),n===16?'est':n===17?'inactive':'sat','Synthetic '+n,n!==15]);
   await db.query("insert into portal_push_releases values($1,now()+($2||' days')::interval)",[id(200+n),n===2||n===3?'-4':'-0.5']);
   if(n===1)continue;
   await db.query(`insert into assignments(id,exam_id,group_id,user_id,created_at)
    values($1,$2,$3,$4,now()-interval '3 days')`,[id(300+n),id(200+n),n%2?id(20):null,n%2?null:id(1)]);
  }
  await db.exec(`
   update assignments set created_at=now() where exam_id='${id(203)}';
   update assignments set open_at=now()+interval '1 hour' where exam_id='${id(204)}';
   update assignments set close_at=now()-interval '1 hour' where exam_id='${id(205)}';
   update assignments set open_at=now(),close_at=now() where exam_id='${id(206)}';
   insert into assignments values('${id(350)}','${id(207)}',null,'${id(1)}',null,null,now());
   insert into assignments values('${id(351)}','${id(207)}','${id(20)}',null,now()+interval '1 hour',null,now());
   insert into assignments values('${id(352)}','${id(208)}','${id(21)}',null,null,null,now());
   insert into enrollments values('${id(1)}','inactive','active',null,null);
   insert into attempts values('${id(401)}','${id(1)}','${id(209)}','in_progress',null,null),
    ('${id(402)}','${id(1)}','${id(210)}','graded',now(),null),
    ('${id(403)}','${id(1)}','${id(211)}','graded',now(),now()+interval '1 hour'),
    ('${id(404)}','${id(1)}','${id(212)}','graded',now()-interval '3 days',null),
    ('${id(405)}','${id(1)}','${id(213)}','graded',now(),now()),
    ('${id(406)}','${id(1)}','${id(214)}','submitted',now(),null);
   insert into portal_push_queue(subscription_id,event_key,kind,title,body,status,created_at)
    values('${id(101)}','exam:${id(218)}','exam','Preserve','Preserve','failed',now()),
     ('${id(101)}','expired:test','test','Preserve','Preserve','pending',now()-interval '25 hours');
  `);
  const queueSQL=`select subscription_id,event_key,kind,title,body,exam_id,status,attempts,error from portal_push_queue order by subscription_id,event_key`;
  async function run(fn){
   await db.exec('savepoint collector_comparison');
   try{await db.query(`select public.${fn}()`);return (await db.query(queueSQL)).rows;}
   finally{await db.exec('rollback to savepoint collector_comparison;release savepoint collector_comparison');}
  }
  const expected=await run('portal_push_collect_before');
  const actual=await run('portal_push_collect');
  assert.deepEqual(actual,expected,'Exact queue output must match the production collector');
  const keys=actual.filter(q=>q.subscription_id===id(101)).map(q=>q.event_key);
  for(const n of [3,6,7,8,18,19,20])assert(keys.includes('exam:'+id(200+n)),`eligible exam ${n}`);
  for(const n of [1,2,4,5,9,10,11,12,13,14,15,16,17])assert(!keys.includes('exam:'+id(200+n)),`ineligible exam ${n}`);
  assert(keys.includes('result:'+id(402)));assert(keys.includes('result:'+id(405)));
  assert(!keys.includes('result:'+id(403)));assert(!keys.includes('result:'+id(404)));
  assert.equal(actual.find(q=>q.event_key==='expired:test').error,'delivery_expired');
  assert.equal(actual.find(q=>q.subscription_id===id(101)&&q.event_key==='exam:'+id(218)).status,'failed');
  await db.query('select public.portal_push_collect()');
  const first=(await db.query(queueSQL)).rows;
  await db.query('select public.portal_push_collect()');
  assert.deepEqual((await db.query(queueSQL)).rows,first,'Second collection does not replay any status');
  // Force only the time-window branch in both reference and implementation;
  // verify opt-in/enrollment/no-replay behavior without depending on wall time.
  const forceReminder=s=>s.replace(/if extract\(hour[^\n]+ then/, 'if true then');
  await db.exec(forceReminder(before).replace('public.portal_push_collect()','public.portal_push_collect_before()'));
  await db.exec(forceReminder(read('supabase/sql/portal_push_collect_performance.sql')));
  await db.exec(`update portal_push_subscriptions set reminders=true where id in ('${id(101)}','${id(102)}')`);
  const reminderRows=await run('portal_push_collect');
  assert.deepEqual(reminderRows,await run('portal_push_collect_before'));
  assert.equal(reminderRows.filter(r=>r.kind==='reminder').length,1,'Only opted-in, enrolled recipient gets reminder');
  await db.query('select public.portal_push_collect()');
  assert.deepEqual(await run('portal_push_collect'),await run('portal_push_collect_before'));
  for(const [t,allowed] of [['17:59:59',false],['18:00:00',true],['18:09:59',true],['18:10:00',false]]){
   const result=(await db.query(`select extract(hour from $1::time)=18 and extract(minute from $1::time)<10 allowed`,[t])).rows[0];
   assert.equal(result.allowed,allowed);
  }
  // Enrollment and profile changes remain effective after a previous collection.
  await db.exec("update tracks set is_active=false where id='sat'");
  assert.deepEqual(await run('portal_push_collect'),await run('portal_push_collect_before'));
  for(const role of ['anon','authenticated']){
   const grants=(await db.query(`select has_function_privilege($1,'public.portal_push_collect()','execute') allowed`,[role])).rows[0];
   assert.equal(grants.allowed,false);
   await db.exec('savepoint role_check;set local role '+role);
   await assert.rejects(()=>db.query('select public.portal_push_collect()'),/permission denied/);
   await db.exec('rollback to savepoint role_check;release savepoint role_check');
  }
  assert.equal((await db.query("select prosecdef from pg_proc where oid='public.portal_push_collect()'::regprocedure")).rows[0].prosecdef,false);
  assert.equal((await db.query("select has_function_privilege('service_role','public.portal_push_collect()','execute') allowed")).rows[0].allowed,true);
  await db.exec('rollback');
  // Existing notification retry/dedup/access checks remain compatible.
  await db.exec(read('tests/portal_notifications.sql'));
 }finally{await db.close();}
});
