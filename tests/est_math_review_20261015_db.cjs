// Isolated PGlite only. No network, Supabase URL, credentials or student fixtures.
const {PGlite}=require(process.env.PGLITE_MODULE||'@electric-sql/pglite');
const fs=require('node:fs'),assert=require('node:assert/strict'),db=new PGlite();
const D='content-releases/20261015_est_math_review/',read=p=>fs.readFileSync(p,'utf8'),load=p=>JSON.parse(read(D+p+'.json'));
const scalar=async(s,a=[])=>Object.values((await db.query(s,a)).rows[0])[0];
const id=n=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
async function main(){
 for(const f of ['tests/00_shim.sql','supabase/migrations/001_schema.sql'])await db.exec(read(f).replaceAll('create extension if not exists pgcrypto;',''));
 await db.exec("insert into tracks(id,name) values('est','EST I'),('est2','EST II');create table revision_items(question_id uuid primary key,lesson text,idea text,difficulty text,programmes text[],fingerprint text,active boolean,focus jsonb);create table revision_sessions(id int primary key,answers jsonb);");
 const before=load('before'),packet=load('packet'),selected=new Set(packet.map(q=>q.id));
 for(const q of before){
  const {correct,explanation,hash,...row}=q;
  await db.query('insert into questions select (jsonb_populate_record(null::questions,$1::jsonb)).*',[JSON.stringify(row)]);
  await db.query('insert into question_keys values($1,$2::jsonb,$3)',[q.id,JSON.stringify(correct),explanation]);
 }
 await db.exec(read('supabase/sql/question_eligibility_core.sql'));
 await db.exec(read('tests/fixtures/oct4-support-functions.sql').match(/CREATE OR REPLACE FUNCTION public.revision_question_fingerprint[\s\S]*?\$function\$;/i)[0]);
 for(const r of load('revision-before'))await db.query('insert into revision_items select (jsonb_populate_record(null::revision_items,$1::jsonb)).*',[JSON.stringify(r)]);
 await db.exec(read('supabase/migrations/002_functions.sql').match(/create or replace function public.norm_num\([\s\S]*?\$\$;/i)[0]);
 await db.exec(read('supabase/sql/numeric_range_keys.sql'));
 await db.query('insert into auth.users(id) values($1)',[id(1)]);await db.query("insert into profiles(id,role) values($1,'student')",[id(1)]);
 await db.query("insert into groups(id,track_id,name) values($1,'est','Synthetic class')",[id(2)]);
 await db.query('insert into group_members values($1,$2)',[id(2),id(1)]);
 await db.query("insert into exams(id,track_id,title,duration_seconds,question_ids,is_published) values($1,'est','Synthetic existing exam',900,$2,true)",[id(3),packet.filter(q=>q.track_id==='est').map(q=>q.id)]);
 await db.query('insert into assignments(id,exam_id,user_id) values($1,$2,$3)',[id(4),id(3),id(1)]);
 await db.query("insert into attempts(id,user_id,exam_id,assignment_id,attempt_no,shuffle_seed,status,deadline_at,score,total) values($1,$2,$3,$4,1,11,'graded',now(),5,14)",[id(5),id(1),id(3),id(4)]);
 await db.exec("insert into revision_sessions values(1,'{\"synthetic\":\"unchanged\"}');");
 await db.query('insert into attempt_answers(attempt_id,question_id,response) values($1,$2,$3::jsonb)',[id(5),packet[0].id,JSON.stringify(packet[0].correct)]);
 await db.query('insert into attempt_results values($1,$2,true,1)',[id(5),packet[0].id]);
 // All production row hashes must be reproducible in a disposable DB.
 for(const q of before)assert.equal(await scalar("select md5(jsonb_build_object('q',to_jsonb(q),'k',to_jsonb(k))::text) from questions q join question_keys k on k.question_id=q.id where q.id=$1",[q.id]),q.hash,q.id);
 const state=async()=>({q:(await db.query('select * from questions order by id')).rows,k:(await db.query('select * from question_keys order by question_id')).rows,r:(await db.query('select * from revision_items order by question_id')).rows});
 const tables=['exams','assignments','attempts','attempt_answers','attempt_results','revision_sessions','enrollments','group_members'];
 const history=async()=>Object.fromEntries(await Promise.all(tables.map(async t=>[t,(await db.query('select * from '+t)).rows])));
 const original=await state(),hist=await history(),sql=read(D+'apply.sql'),rollback=read(D+'rollback.sql'),last=packet.at(-1);
 await db.query("update questions set assets=assets||'{\"concurrent\":true}' where id=$1",[last.id]);
 await assert.rejects(()=>db.exec(sql),/Concurrent content change/);await db.exec('rollback');
 assert.equal(await scalar('select count(*)::int from audit_log'),0);
 assert.deepEqual((await state()).k,original.k);
 await db.query('update questions set assets=$2 where id=$1',[last.id,JSON.stringify(before.find(q=>q.id===last.id).assets)]);
 await db.query('update question_keys set explanation=explanation||$2 where question_id=$1',[last.id,' concurrent']);
 await assert.rejects(()=>db.exec(sql),/Concurrent content change/);await db.exec('rollback');
 await db.query('update question_keys set explanation=$2 where question_id=$1',[last.id,before.find(q=>q.id===last.id).explanation]);
 await db.exec("update revision_items set fingerprint='stale'");
 await assert.rejects(()=>db.exec(sql),/Stale revision fingerprint/);await db.exec('rollback');
 await db.query('update revision_items set fingerprint=$1',[load('revision-before')[0].fingerprint]);
 await db.exec(sql);
 const after=await state();assert.deepEqual(await history(),hist);
 for(const q of after.q){
  const old=original.q.find(x=>x.id===q.id),change=packet.find(x=>x.id===q.id);
  if(!change){assert.deepEqual(q,old);continue;}
  assert.equal(q.assets.answer_review_status,'independently_solved');
  assert.deepEqual({...q,assets:old.assets,choices:old.choices},old);
  for(const [k,v] of Object.entries(old.assets))assert.deepEqual(q.assets[k],v);
  assert.equal(q.assets.image,old.assets.image);
  assert.deepEqual(q.choices,change.choices);
  assert.equal(await scalar("select portal_private.question_eligible(q,k,q.track_id,false) from questions q join question_keys k on k.question_id=q.id where q.id=$1",[q.id]),true);
 }
 assert.equal(after.q.filter(q=>JSON.stringify(q.choices)!==JSON.stringify(original.q.find(x=>x.id===q.id).choices)).length,2);
 for(const k of after.k){assert.deepEqual(k.correct,original.k.find(x=>x.question_id===k.question_id).correct);
  const p=packet.find(q=>q.id===k.question_id);
  if(p)assert.equal(k.explanation,p.explanation);
 }
 assert.deepEqual(after.r.map(r=>({...r,fingerprint:''})),original.r.map(r=>({...r,fingerprint:''})));
 assert.equal(await scalar("select r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation) from revision_items r join questions q on q.id=r.question_id join question_keys k on k.question_id=q.id"),true);
 for(const p of packet){
  const row=before.find(q=>q.id===p.id);
  if(row.type==='mcq')for(const c of p.choices)assert.equal(await scalar('select answer_matches($1,$2::jsonb,$3::jsonb)',[row.type,JSON.stringify(c.key),JSON.stringify(p.correct)]),c.key===p.correct);
  else{
   const responses=Array.isArray(p.correct)?p.correct:[p.correct];
   for(const r of responses)assert.equal(await scalar('select answer_matches($1,$2::jsonb,$3::jsonb)',[row.type,JSON.stringify(r),JSON.stringify(p.correct)]),true);
   for(const wrong of ['-99999','NaN','Infinity'])assert.equal(await scalar('select answer_matches($1,$2::jsonb,$3::jsonb)',[row.type,JSON.stringify(wrong),JSON.stringify(p.correct)]),false);
  }
 }
 const prob=packet.find(q=>q.source_code==='CP-c24-02');
 assert.equal(await scalar("select answer_matches('grid_in','\"22/60\"',$1::jsonb)",[JSON.stringify(prob.correct)]),true);
 assert.equal(await scalar("select answer_matches('grid_in','\"36.7\"',$1::jsonb)",[JSON.stringify(prob.correct)]),false);
 await assert.rejects(()=>db.exec(sql),/already applied/);await db.exec('rollback');
 await db.query('update questions set stem=stem||$2 where id=$1',[last.id,' later']);
 await assert.rejects(()=>db.exec(rollback),/Concurrent post-release edit/);await db.exec('rollback');
 await db.query('update questions set stem=$2 where id=$1',[last.id,before.find(q=>q.id===last.id).stem]);
 await db.exec(rollback);
 assert.deepEqual(await state(),original);assert.deepEqual(await history(),hist);
 await assert.rejects(()=>db.exec(rollback),/already rolled back/);await db.exec('rollback');
 console.log('PASS: exact production fingerprints; atomic late-conflict/key/revision rejection; 28 records, two choice repairs, unchanged accepted keys and all history/assessments; numeric grader and MCQ checks; source metadata preserved; revision fingerprint refreshed; replay and guarded rollback.');
 await db.close();
}main().catch(async e=>{console.error(e);await db.close();process.exitCode=1});
