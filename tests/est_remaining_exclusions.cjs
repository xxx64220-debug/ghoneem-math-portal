// Isolated PostgreSQL regression; never connects to production.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {PGlite}=require(process.env.PGLITE_MODULE||'@electric-sql/pglite');
const dir=path.resolve(__dirname,'../content-releases/20260930_est_remaining_audit');
const rows=JSON.parse(fs.readFileSync(path.join(dir,'source-defect-exclusions-input.json')));
const db=new PGlite();
(async()=>{
 await db.exec(`create table questions(id uuid primary key,track_id text,stem text,choices jsonb,assets jsonb);
 create table question_keys(question_id uuid primary key,correct jsonb,explanation text);
 create table revision_items(question_id uuid primary key,lesson text,idea text,difficulty text,programmes text[],focus jsonb,active boolean);
 create table exams(id uuid primary key,is_published boolean,question_ids uuid[]);
 create table audit_log(action text,target_type text,target_id text,meta jsonb);`);
 let sql=fs.readFileSync(path.join(dir,'source-defect-exclusions.sql'),'utf8');
 for(const q of rows){
  await db.query('insert into questions values($1,$2,$3,$4,$5)',[q.id,'est',q.stem,JSON.stringify(q.choices),JSON.stringify(q.assets)]);
  await db.query('insert into question_keys values($1,$2,$3)',[q.id,JSON.stringify(q.correct),q.explanation]);
  await db.query("insert into revision_items values($1,'Systems of equations','No-solution conditions','medium',array['est'],'{}',true)",[q.id]);
  await db.query('insert into exams values($1,true,array[$1]::uuid[])',[q.id]);
  const a=(await db.query('select md5(to_jsonb(q)::text) q_digest,md5(to_jsonb(k)::text) key_digest from questions q join question_keys k on k.question_id=q.id where q.id=$1',[q.id])).rows[0];
  sql=sql.replaceAll(q.q_digest,a.q_digest).replaceAll(q.key_digest,a.key_digest);
 }
 const keys=(await db.query('select * from question_keys order by question_id')).rows;
 const memberships=(await db.query('select id,question_ids from exams order by id')).rows;
 await db.exec(sql);
 assert.deepEqual((await db.query('select * from question_keys order by question_id')).rows,keys);
 assert.deepEqual((await db.query('select id,question_ids from exams order by id')).rows,memberships);
 assert.equal((await db.query('select count(*)::int n from revision_items where active')).rows[0].n,0);
 assert.equal((await db.query('select count(*)::int n from exams where is_published')).rows[0].n,0);
 assert.equal((await db.query("select count(*)::int n from questions where length(assets->>'release_hold_reason')>20")).rows[0].n,4);
 assert.equal((-2-44)/(1+3),-11.5);
 // Determinants: three options admit unique solutions; the keyed option does not.
 assert.deepEqual([-1/3,-6,-2/3,2/3].map(k=>Math.abs(-10-15*k)<1e-10),[false,false,true,false]);
 await assert.rejects(()=>db.exec(sql),/already applied/i);await db.exec('rollback');
 console.log('PASS: defective source exclusions block publication and preserve keys and history memberships.');await db.close();
})().catch(async e=>{console.error(e);await db.close();process.exitCode=1;});
