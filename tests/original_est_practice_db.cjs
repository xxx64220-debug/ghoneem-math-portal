const fs=require('node:fs');
const assert=require('node:assert/strict');
const {PGlite}=require(process.env.PGLITE_MODULE||'./june-review-runtime/node_modules/@electric-sql/pglite');
const path='content-releases/20261006_original_est_practice/';
const sql=fs.readFileSync(path+'apply.sql','utf8');
const review=JSON.parse(fs.readFileSync(path+'review.json','utf8'));
const payload=JSON.parse(sql.match(/\$payload\$([\s\S]*?)\$payload\$/)[1]);
assert.deepEqual(payload.questions,review.questions.map(({review_figure_spec,...q})=>q));
const oldId='00000000-0000-0000-0000-000000000001';
const historyId='00000000-0000-0000-0000-000000000002';
async function setup(){
 const db=new PGlite();
 await db.exec(`create role anon;create role authenticated;create role service_role;
 create table questions(id uuid primary key,track_id text,topic text,difficulty text,type text,stem text,choices jsonb,assets jsonb,created_at timestamptz default now());
 create table question_keys(question_id uuid primary key references questions(id),correct jsonb,explanation text);
 create table audit_log(id bigserial primary key,action text,target_type text,target_id text,meta jsonb);
 create table exams(id uuid primary key,question_ids uuid[],track_id text default 'est',is_published boolean default false);create table revision_items(question_id uuid primary key);
 create table assignments(id uuid primary key,exam_id uuid);create table attempts(id uuid primary key,assignment_id uuid,answers jsonb,score numeric);
 insert into questions(id,track_id,topic,type,stem,choices,assets) values('${oldId}','est','Circles','mcq','Existing protected question','[{"key":"A","text":"1"},{"key":"B","text":"2"}]','{"figure":"preserved","release_hold_reason":"held"}');
 insert into question_keys values('${oldId}','"A"','Existing protected explanation');
 insert into exams(id,question_ids) values('${historyId}',array['${oldId}'::uuid]);
 insert into revision_items values('${oldId}');
 insert into assignments values('${historyId}','${historyId}');
 insert into attempts values('${historyId}','${historyId}','{"answer":"A"}',100);`);
 await db.exec(fs.readFileSync('supabase/sql/question_eligibility_core.sql','utf8'));
 return db;
}
async function snapshot(db){
 const out={};
 for(const t of ['questions','question_keys','exams','revision_items','assignments','attempts']){
  const filter=t==='questions'?`where id='${oldId}'`:t==='question_keys'?`where question_id='${oldId}'`:'';
  out[t]=(await db.query(`select * from ${t} ${filter}`)).rows;
 }
 return out;
}
async function count(db,t){return (await db.query(`select count(*)::int n from ${t}`)).rows[0].n}
async function reject(db,s,pattern){await assert.rejects(db.exec(s),pattern);await db.exec('rollback');}
function mutated(fn){const p=structuredClone(payload);fn(p);return sql.replace(/\$payload\$[\s\S]*?\$payload\$/,()=>'$payload$'+JSON.stringify(p)+'$payload$');}
(async()=>{
 let db=await setup(),before=await snapshot(db);
 await db.exec(sql);
 assert.equal(await count(db,'questions'),51);assert.equal(await count(db,'question_keys'),51);assert.equal(await count(db,'audit_log'),1);
 assert.deepEqual(await snapshot(db),before);
 for(const p of payload.questions){
  const q=(await db.query('select * from questions where id=$1',[p.id])).rows[0];
  const k=(await db.query('select * from question_keys where question_id=$1',[p.id])).rows[0];
  assert.deepEqual(q.assets,p.assets);assert.deepEqual(q.choices,p.choices);assert.equal(q.stem,p.stem);
  assert.equal(k.correct,p.correct);assert.equal(k.explanation,p.explanation);
 }
 const eligible=(await db.query(`select count(*)::int n from questions q join question_keys k on k.question_id=q.id where q.assets->>'practice_collection'=$1 and portal_private.question_eligible(q,k,'est',true)`,[payload.release])).rows[0].n;
 assert.equal(eligible,50);
 await reject(db,sql,/already applied/);assert.equal(await count(db,'questions'),51);await db.close();
 for(const [name,fn,pattern] of [
  ['late blank explanation',p=>p.questions[49].explanation='',/Invalid candidate/],
  ['late invalid key',p=>p.questions[49].correct='E',/Invalid candidate/],
  ['required figure',p=>delete p.questions[49].assets.figure,/Missing required figure/],
  ['public answer leak',p=>p.questions[49].assets.correct='B',/Invalid candidate/],
  ['wrong track',p=>p.questions[49].track_id='act',/Invalid candidate/],
  ['duplicate choices',p=>p.questions[49].choices[1].text=p.questions[49].choices[0].text,/Invalid candidate/],
  ['duplicate payload ID',p=>p.questions[49].id=p.questions[0].id,/Duplicate payload identity/],
  ['short packet',p=>p.questions.pop(),/Unexpected packet count/]
 ]){
  db=await setup();before=await snapshot(db);await reject(db,mutated(fn),pattern);
  assert.equal(await count(db,'questions'),1,name);assert.equal(await count(db,'question_keys'),1,name);
  assert.equal(await count(db,'audit_log'),0,name);assert.deepEqual(await snapshot(db),before,name);await db.close();
 }
 for(const collision of ['id','source','stem']){
  db=await setup();const last=payload.questions[49];
  if(collision==='id')await db.query('update questions set id=$1 where id=$2',[last.id,oldId]).catch(async()=>{
   // Preserve the protected FK fixture and insert a separate colliding candidate.
   await db.query("insert into questions(id,track_id,stem,choices,assets) values($1,'est','Colliding identity','[]','{}')",[last.id]);
  });
  if(collision==='source')await db.query('update questions set assets=$1 where id=$2',[JSON.stringify({source_code:last.assets.source_code}),oldId]);
  if(collision==='stem')await db.query('update questions set stem=$1 where id=$2',[last.stem,oldId]);
  const nq=await count(db,'questions');before=await snapshot(db);
  await reject(db,sql,collision==='stem'?/Duplicate stem/:/already present/);
  assert.equal(await count(db,'questions'),nq);assert.equal(await count(db,'audit_log'),0);assert.deepEqual(await snapshot(db),before);await db.close();
 }
 console.log('PASS: isolated 50-question insert, exact content and keys, daily eligibility, student history preservation, replay/collision rejection and atomic late-failure rollback');
})().catch(e=>{console.error(e);process.exit(1)});
