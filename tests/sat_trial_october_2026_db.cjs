// Offline PGlite only; no network or production credentials.
const fs=require('node:fs'),assert=require('node:assert/strict');
const {PGlite}=require(process.env.PGLITE_MODULE||'./june-review-runtime/node_modules/@electric-sql/pglite');
const path='content-releases/20261017_sat_trial_october_2026/';
const sql=fs.readFileSync(path+'apply.sql','utf8'),packet=JSON.parse(fs.readFileSync(path+'review.json','utf8'));
assert.deepEqual(JSON.parse(sql.match(/\$payload\$([\s\S]*?)\$payload\$/)[1]),packet);
const old='00000000-0000-4000-8000-000000000001',hist='00000000-0000-4000-8000-000000000002';
const scalar=async(db,q,args=[])=>Object.values((await db.query(q,args)).rows[0])[0];
async function setup(){
 const db=new PGlite();
 await db.exec(`create role anon;create role authenticated;create role service_role;
 create table questions(id uuid primary key,track_id text,topic text,difficulty text,type text,stem text,choices jsonb,assets jsonb,created_at timestamptz default now());
 create table question_keys(question_id uuid primary key references questions(id),correct jsonb,explanation text);
 create table audit_log(id bigserial primary key,action text,target_type text,target_id text,meta jsonb);
 create table exams(id uuid primary key,question_ids uuid[],track_id text,is_published boolean);
 create table attempts(id uuid primary key,answers jsonb,score numeric);
 insert into questions values('${old}','est','Circles','easy','mcq','Protected original','[{"key":"A","text":"1"},{"key":"B","text":"2"}]','{"release_hold_reason":"Do not change","figure":"retained"}',now());
 insert into question_keys values('${old}','"A"','Protected explanation');
 insert into exams values('${hist}',array['${old}'::uuid],'est',false);
 insert into attempts values('${hist}','{"original":"B"}',75);
 alter table question_keys enable row level security;revoke all on question_keys from public,anon,authenticated;`);
 await db.exec(fs.readFileSync('supabase/sql/question_eligibility_core.sql','utf8'));
 const original=fs.readFileSync('supabase/migrations/002_functions.sql','utf8');
 await db.exec(original.slice(original.indexOf('create or replace function public.norm_num('),original.indexOf('create or replace function public.answer_matches(')));
 const grader=fs.readFileSync('supabase/sql/fair_exam_keys.sql','utf8');await db.exec(grader.slice(grader.indexOf('create or replace function public.answer_matches('),grader.indexOf('-- Excluded source defects')));
 return db;
}
async function snapshot(db){let out={};for(const t of ['questions','question_keys','exams','attempts'])out[t]=(await db.query(`select * from ${t} ${t==='questions'?`where id='${old}'`:t==='question_keys'?`where question_id='${old}'`:''}`)).rows;return out;}
function changed(fn){const p=structuredClone(packet);fn(p);return sql.replace(/\$payload\$[\s\S]*?\$payload\$/,()=>'$payload$'+JSON.stringify(p)+'$payload$');}
async function reject(db,query,rx){await assert.rejects(db.exec(query),rx);await db.exec('rollback');}
(async()=>{
 let db=await setup(),before=await snapshot(db);await db.exec(sql);
 assert.equal(await scalar(db,'select count(*)::int from questions'),138);assert.equal(await scalar(db,'select count(*)::int from question_keys'),138);assert.deepEqual(await snapshot(db),before);
 for(const p of packet.questions){
  const q=(await db.query('select * from questions where id=$1',[p.id])).rows[0],k=(await db.query('select * from question_keys where question_id=$1',[p.id])).rows[0];
  for(const field of ['track_id','topic','difficulty','type','stem','choices','assets'])assert.deepEqual(q[field],p[field]);
  assert.deepEqual(k.correct,p.correct);assert.equal(k.explanation,p.explanation);
  assert.equal(await scalar(db,'select answer_matches($1,$2::jsonb,$3::jsonb)',[p.type,JSON.stringify(p.correct),JSON.stringify(p.correct)]),true);
  assert.equal(await scalar(db,'select answer_matches($1,$2::jsonb,$3::jsonb)',[p.type,JSON.stringify(p.type==='mcq'?(p.correct==='A'?'B':'A'):String(Number(p.correct)+1)),JSON.stringify(p.correct)]),false);
 }
 assert.equal(await scalar(db,"select count(*)::int from questions q join question_keys k on q.id=k.question_id where portal_private.question_eligible(q,k,'sat',false)"),137);
 assert.equal(await scalar(db,"select count(*)::int from questions q join question_keys k on q.id=k.question_id where portal_private.question_eligible(q,k,'sat',true)"),106);
 assert.equal(await scalar(db,"select count(*)::int from questions where strpos(lower(concat_ws(' ',assets->>'source_document',assets->>'source')),lower('SAT Trial 2026 October'))>0"),137);
 assert.equal(await scalar(db,`select answer_matches('grid_in','"457/100"','"4.57"')`),true);
 for(const role of ['anon','authenticated']){await db.exec('set role '+role);await assert.rejects(db.query('select * from question_keys'),/permission denied/);await db.exec('reset role');}
 await reject(db,sql,/already applied/);assert.deepEqual(await snapshot(db),before);await db.close();
 for(const [name,fn,rx] of [
  ['late empty solution',p=>p.questions.at(-1).explanation='',/Invalid candidate/],
  ['late wrong track',p=>p.questions.at(-1).track_id='est',/Invalid candidate/],
  ['late public key',p=>p.questions.at(-1).assets.correct='550',/Invalid candidate/],
  ['late bad numeric key',p=>p.questions.at(-1).correct='NaN',/Invalid grid-in key/],
  ['late missing graphic',p=>delete p.questions.filter(q=>q.assets.figure).at(-1).assets.figure,/Missing required figure/],
  ['late changed graphic',p=>p.questions.filter(q=>q.assets.figure).at(-1).assets.figure_sha256='00',/Figure hash mismatch/],
  ['repeated identity',p=>p.questions.at(-1).id=p.questions[0].id,/Duplicate payload identity/],
  ['invalid MCQ',p=>p.questions.filter(q=>q.type==='mcq').at(-1).correct='E',/Invalid choices\/key/]
 ]){
  db=await setup();before=await snapshot(db);await reject(db,changed(fn),rx);
  assert.equal(await scalar(db,'select count(*)::int from questions'),1,name);assert.equal(await scalar(db,'select count(*)::int from question_keys'),1,name);assert.equal(await scalar(db,'select count(*)::int from audit_log'),0,name);assert.deepEqual(await snapshot(db),before,name);await db.close();
 }
 db=await setup();before=await snapshot(db);const last=packet.questions.at(-1);
 await db.query("insert into questions(id,track_id,stem,choices,assets) values($1,'sat','Existing source identity','[]',$2::jsonb)",['00000000-0000-4000-8000-000000000099',JSON.stringify({source_code:last.assets.source_code})]);
 await reject(db,sql,/Candidate already present/);assert.equal(await scalar(db,'select count(*)::int from questions'),2);assert.equal(await scalar(db,'select count(*)::int from audit_log'),0);assert.deepEqual(await snapshot(db),before);await db.close();
 console.log('PASS: exact 137-row SQL application; actual key grader; 31 grid-in / 106 daily MCQs; old records/history/private-key access preserved; replay, late collisions, corrupt choices/keys and missing/changed graphics roll back atomically.');
})().catch(e=>{console.error(e.message);process.exitCode=1;});
