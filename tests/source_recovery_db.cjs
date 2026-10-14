// Local PostgreSQL/WASM only. No network or production connection.
const {PGlite}=require(process.env.PGLITE_MODULE||'@electric-sql/pglite');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'),read=f=>fs.readFileSync(path.join(root,f),'utf8');
const dir='content-releases/20261004_source_recovery/';
const rows=JSON.parse(read(dir+'before.json')),patches=JSON.parse(read(dir+'repairs.json'));
const id=n=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
async function scenario(held){
 const db=new PGlite();
 try{
  for(const f of ['tests/00_shim.sql','supabase/migrations/001_schema.sql'])await db.exec(read(f).replace(/create extension if not exists pgcrypto;/g,''));
  await db.exec(`alter table exams add column is_full_length boolean default false,add column assessment_type text default 'lesson_exam',add column scoring_map jsonb,add column exam_set_code text,add column module_number int,add column module_count int;
   create table revision_items(question_id uuid primary key,fingerprint text,active boolean);
   create function revision_question_fingerprint(text,jsonb,jsonb,jsonb,text) returns text language sql as $$select md5(jsonb_build_array($1,$2,$3,$4,$5)::text)$$;
   insert into tracks(id,name) values('sat','SAT'),('est','EST');
   insert into auth.users(id) values('${id(1)}');insert into profiles(id,role) values('${id(1)}','student');`);
  for(const q of rows){
   const assets={...q.assets,...(held?{release_hold_reason:patches.find(p=>p.id===q.id).expected_hold}:{})};
   await db.query('insert into questions(id,track_id,topic,type,stem,choices,assets) values($1,$2,$3,$4,$5,$6,$7)',[q.id,q.track_id,q.topic,q.type,q.stem,q.choices,assets]);
   await db.query('insert into question_keys values($1,$2,$3)',[q.id,JSON.stringify(q.correct),q.explanation]);
   await db.query("insert into revision_items values($1,'old-fingerprint',false)",[q.id]);
  }
  for(let i=0;i<4;i++){
   const q=rows[i%3];
   await db.query("insert into exams(id,track_id,title,duration_seconds,question_ids,is_published,assessment_type,shuffle,review_policy,max_attempts,scoring_map) values($1,$2,$3,600,$4,true,'quiz',false,'full_review',1,$5)",[id(10+i),q.track_id,'Source exam '+i,[q.id],{raw:'fixture'}]);
   await db.query('insert into assignments(exam_id,user_id,open_at,close_at) values($1,$2,$3,$4)',[id(10+i),id(1),'2026-01-01T00:00:00Z','2026-12-01T00:00:00Z']);
  }
  await db.query("insert into attempts(id,user_id,exam_id,assignment_id,attempt_no,shuffle_seed,deadline_at,status,score,total,review_unlocks_at) select $1,$2,$3,id,1,42,now(),'graded',1,1,now() from assignments where exam_id=$3",[id(30),id(1),id(10)]);
  await db.query('insert into attempt_answers(attempt_id,question_id,response) values($1,$2,$3)',[id(30),rows[0].id,'"A"']);
  await db.query('insert into attempt_results values($1,$2,true,1)',[id(30),rows[0].id]);
  const snapshot=async()=>(await db.query(`select jsonb_build_object('attempts',(select jsonb_agg(to_jsonb(a)) from attempts a),'answers',(select jsonb_agg(to_jsonb(a)) from attempt_answers a),'results',(select jsonb_agg(to_jsonb(a)) from attempt_results a)) history`)).rows[0].history;
  const before=await snapshot(),oldExams=(await db.query('select * from exams order by id')).rows;
  const last=rows.at(-1);await db.query('update question_keys set explanation=explanation||$2 where question_id=$1',[last.id,' concurrent']);
  await assert.rejects(()=>db.exec(read(dir+'apply.sql')),/Concurrent content change/);await db.exec('rollback');
  assert.equal((await db.query('select count(*) n from audit_log')).rows[0].n,0);
  assert.deepEqual((await db.query('select * from exams order by id')).rows,oldExams);
  await db.query('update question_keys set explanation=$2 where question_id=$1',[last.id,last.explanation]);
  // Live attempts block rollout without modifying them.
  await db.query("update attempts set status='in_progress' where id=$1",[id(30)]);
  await assert.rejects(()=>db.exec(read(dir+'apply.sql')),/active attempt/);await db.exec('rollback');
  await db.query("update attempts set status='graded' where id=$1",[id(30)]);
  await db.exec(read(dir+'apply.sql'));assert.deepEqual(await snapshot(),before);
  const now=(await db.query('select q.*,k.correct,k.explanation from questions q join question_keys k on k.question_id=q.id')).rows;
  for(const p of patches){const q=now.find(q=>q.id===p.id);assert.equal(q.assets.release_hold_reason,undefined);assert.equal(q.correct,p.correct);assert.equal(q.explanation,p.explanation);if(p.choices)assert.deepEqual(q.choices,p.choices);if(p.asset_patch.figure)assert.equal(q.assets.figure,p.asset_patch.figure);}
  const replacements=(await db.query("select * from exams where is_published order by title")).rows;assert.equal(replacements.length,4);
  for(const e of oldExams){const n=replacements.find(n=>n.title===e.title+' — Source-corrected v2 (Oct 2026)');assert.ok(n);for(const key of ['track_id','question_ids','duration_seconds','shuffle','review_policy','max_attempts','assessment_type','scoring_map'])assert.deepEqual(n[key],e[key]);assert.equal((await db.query('select is_published from exams where id=$1',[e.id])).rows[0].is_published,false);assert.deepEqual((await db.query('select user_id,group_id,open_at,close_at from assignments where exam_id=$1',[n.id])).rows,(await db.query('select user_id,group_id,open_at,close_at from assignments where exam_id=$1',[e.id])).rows);}
  assert.equal((await db.query('select count(*) n from revision_items where active')).rows[0].n,0);
  await assert.rejects(()=>db.exec(read(dir+'apply.sql')),/already applied/);await db.exec('rollback');assert.deepEqual(await snapshot(),before);
  // Rollback is refused after a replacement has been attempted.
  await db.query("insert into attempts(id,user_id,exam_id,attempt_no,shuffle_seed,deadline_at,status) values($1,$2,$3,1,1,now(),'expired')",[id(31),id(1),replacements[0].id]);
  await assert.rejects(()=>db.exec(read(dir+'rollback.sql')),/Replacement has attempts/);await db.exec('rollback');
  await db.query('delete from attempts where id=$1',[id(31)]);
  await db.exec(read(dir+'rollback.sql'));assert.deepEqual(await snapshot(),before);
  for(const r of rows){const q=(await db.query('select q.*,k.correct,k.explanation from questions q join question_keys k on k.question_id=q.id where q.id=$1',[r.id])).rows[0];assert.deepEqual(q.choices,r.choices);assert.equal(q.explanation,r.explanation);assert.equal(q.assets.release_hold_reason,held?patches.find(p=>p.id===r.id).expected_hold:undefined);}
  console.log('PASS source recovery:',held?'held release':'pre-release live state','; authentic repairs, stable keys, late rollback, active-attempt refusal, four clean versions, preserved audience/windows, unchanged attempts/answers/scores, replay guard.');
 }finally{await db.close();}
}
(async()=>{await scenario(false);await scenario(true);})().catch(e=>{console.error(e);process.exitCode=1;});
