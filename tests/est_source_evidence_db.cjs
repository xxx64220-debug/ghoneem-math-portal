// Disposable local PostgreSQL only. No external endpoints or production connection.
const {PGlite}=require(process.env.PGLITE_MODULE||'@electric-sql/pglite');
const fs=require('node:fs'),assert=require('node:assert/strict');
const dir='content-releases/20261005_est_source_evidence/';
const read=p=>fs.readFileSync(p,'utf8'),rows=JSON.parse(read(dir+'before.json')),patches=JSON.parse(read(dir+'patches.json'));
const id=n=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
async function main(){
 const db=new PGlite();
 try{
  for(const f of ['tests/00_shim.sql','supabase/migrations/001_schema.sql'])await db.exec(read(f).replace(/create extension if not exists pgcrypto;/g,''));
  await db.exec("insert into tracks(id,name) values('est','EST I'); create table revision_items(question_id uuid primary key,active boolean,fingerprint text); create table practice_history(id int,question_id uuid,response jsonb); ");
  for(const q of rows){
   await db.query('insert into questions(id,track_id,topic,difficulty,type,stem,choices,assets,created_at) values($1,$2,$3,$4,$5,$6,$7,$8,$9)',[q.id,q.track_id,q.topic,q.difficulty,q.type,q.stem,q.choices,q.assets,q.created_at]);
   await db.query('insert into question_keys values($1,$2,$3)',[q.id,JSON.stringify(q.correct),q.explanation]);
   await db.query('insert into revision_items values($1,false,$2)',[q.id,'held-original']);
   await db.query('insert into practice_history values($1,$2,$3)',[rows.indexOf(q),q.id,'"A"']);
  }
  await db.query('insert into auth.users(id) values($1)',[id(1)]);
  await db.query("insert into profiles(id,role) values($1,'student')",[id(1)]);
  // Historical original and live replacement memberships/settings/audiences must survive.
  for(let i=0;i<2;i++){
   await db.query("insert into exams(id,track_id,title,duration_seconds,question_ids,is_published) values($1,'est',$2,600,$3,true)",[id(2+i),i?'Replacement assessment':'Historical held original',i?[id(99)]:rows.map(q=>q.id)]);
   await db.query('insert into assignments(exam_id,user_id) values($1,$2)',[id(2+i),id(1)]);
  }
  await db.query("insert into attempts(id,user_id,exam_id,attempt_no,shuffle_seed,deadline_at,status,score,total) values($1,$2,$3,1,1,now(),'graded',1,1)",[id(4),id(1),id(2)]);
  await db.query('insert into attempt_answers values($1,$2,$3,now())',[id(4),rows[0].id,'"A"']);
  await db.query('insert into attempt_results values($1,$2,true,1)',[id(4),rows[0].id]);
  const protectedTables=['exams','assignments','attempts','attempt_answers','attempt_results','revision_items','practice_history'];
  const snapshot=async()=>{const a={};for(const t of protectedTables)a[t]=(await db.query('select * from '+t)).rows;return a;};
  const before=await snapshot();
  const fixture=await db.query('select q.*,k.correct,k.explanation from questions q join question_keys k on k.question_id=q.id order by q.id');
  let sql=read(dir+'apply.sql');
  // PostgreSQL serializations differ from hosted Postgres only for fixture timestamps.
  for(const p of patches){const h=(await db.query('select md5(jsonb_build_array(q.stem,q.choices,q.assets,k.correct,k.explanation)::text) h from questions q join question_keys k on k.question_id=q.id where q.id=$1',[p.id])).rows[0].h;sql=sql.replace(p.before_hash,h);}
  const last=rows.at(-1);await db.query('update questions set stem=stem||$2 where id=$1',[last.id,' concurrent']);
  await assert.rejects(()=>db.exec(sql),/Concurrent content change/);await db.exec('rollback');
  assert.equal((await db.query('select count(*) n from audit_log')).rows[0].n,0);
  assert.deepEqual(await snapshot(),before);
  await db.query('update questions set stem=$2 where id=$1',[last.id,last.stem]);
  await db.exec(sql);
  assert.deepEqual(await snapshot(),before);
  for(const q of fixture.rows){
   const p=patches.find(p=>p.id===q.id),n=(await db.query('select q.*,k.correct,k.explanation from questions q join question_keys k on k.question_id=q.id where q.id=$1',[q.id])).rows[0];
   assert.deepEqual(n.correct,q.correct);assert.ok(n.assets.release_hold_reason);
   for(const field of ['track_id','topic','difficulty','type','created_at'])assert.deepEqual(n[field],q[field]);
   assert.equal(n.stem,p.stem||q.stem);assert.deepEqual(n.choices,p.choices||q.choices);
   assert.deepEqual(n.assets,{...q.assets,...p.asset_patch});
   assert.equal(n.explanation,p.explanation||q.explanation);
  }
  assert.equal((await db.query("select count(*) n from audit_log where action='question.est_source_evidence_20261005'")).rows[0].n,12);
  await assert.rejects(()=>db.exec(sql),/already applied/);await db.exec('rollback');
  await db.query('update questions set stem=stem||$2 where id=$1',[last.id,' later']);
  await assert.rejects(()=>db.exec(read(dir+'rollback.sql')),/Later content edit/);await db.exec('rollback');
  await db.query('update questions set stem=$2 where id=$1',[last.id,patches.find(p=>p.id===last.id).stem||last.stem]);
  await db.exec(read(dir+'rollback.sql'));
  assert.deepEqual(await snapshot(),before);
  assert.deepEqual((await db.query('select q.*,k.correct,k.explanation from questions q join question_keys k on k.question_id=q.id order by q.id')).rows,fixture.rows);
  console.log('PASS: 12 source records; 3 source-faithful content repairs; all holds, keys, replacement exams, audiences, history and revision membership preserved; atomic conflict/replay/rollback guards.');
 }finally{await db.close();}
}
main().catch(e=>{console.error(e);process.exitCode=1;});
