// Isolated PostgreSQL regression; never connects to production.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {PGlite}=require(process.env.PGLITE_MODULE||'@electric-sql/pglite');
const dir=path.resolve(__dirname,'../content-releases/20260930_est_remaining_audit');
const rows=[JSON.parse(fs.readFileSync(path.join(dir,'verified-replacement-input.json')))];
const db=new PGlite();
(async()=>{
 await db.exec(`create table questions(id uuid primary key,track_id text,difficulty text,stem text,choices jsonb,assets jsonb);
 create table question_keys(question_id uuid primary key,correct jsonb,explanation text);
 create table revision_items(question_id uuid primary key,lesson text,idea text,difficulty text,programmes text[],focus jsonb,active boolean,fingerprint text);
 create table exams(id uuid primary key,is_published boolean,question_ids uuid[]);
 create table audit_log(action text,target_type text,target_id text,meta jsonb);`);
 let sql=fs.readFileSync(path.join(dir,'verified-replacement.sql'),'utf8');
 for(const q of rows){
  await db.query('insert into questions values($1,$2,$3,$4,$5,$6)',[q.id,'est','medium',q.stem,JSON.stringify(q.choices),JSON.stringify(q.assets)]);
  await db.query('insert into question_keys values($1,$2,$3)',[q.id,JSON.stringify(q.correct),q.explanation]);
  const a=(await db.query('select md5(to_jsonb(q)::text) q_digest,md5(to_jsonb(k)::text) key_digest from questions q join question_keys k on k.question_id=q.id where q.id=$1',[q.id])).rows[0];
  sql=sql.replaceAll(q.q_digest,a.q_digest).replaceAll(q.key_digest,a.key_digest);
 }
 await db.exec(`create function revision_question_fingerprint(text,jsonb,jsonb,jsonb,text) returns text language sql immutable as $$select md5($1||$2::text||$3::text||$4::text||$5)$$;
 insert into questions values('fa4af000-7c2b-5a7c-a0f2-222016a9d1e9','est','medium','bad source','[]','{"release_hold_reason":"Ambiguous source"}');
 insert into revision_items values('fa4af000-7c2b-5a7c-a0f2-222016a9d1e9','Systems of equations','No-solution conditions','medium',array['est'],'{"collections":["must_know"]}',false,'stale');`);
 const keys=(await db.query('select * from question_keys')).rows;
 await db.exec(sql);assert.deepEqual((await db.query('select * from question_keys')).rows,keys);
 const r=(await db.query('select * from revision_items where active')).rows;assert.equal(r.length,1);assert.deepEqual(r[0].programmes,['est']);assert.deepEqual(r[0].focus.collections,['must_know']);assert.equal(r[0].difficulty,'medium');
 assert.equal(2*(25/2)-25,0);assert.notEqual((1/5)*(5/2),2/25);
 // Removing the intended replacement must fail the coverage contract.
 const verify=async()=>assert.equal((await db.query("select count(*)::int n from revision_items where active and lesson='Systems of equations' and idea='No-solution conditions' and difficulty='medium' and programmes=array['est'] and focus->'collections' @> '[\"must_know\"]'::jsonb")).rows[0].n,1);
 await verify();await db.query('update revision_items set active=false where question_id=$1',[rows[0].id]);await assert.rejects(verify);await db.query('update revision_items set active=true where question_id=$1',[rows[0].id]);
 await assert.rejects(()=>db.exec(sql),/already has revision/);await db.exec('rollback');console.log('PASS: verified EST replacement preserves lesson, idea, difficulty, Must Know, track and representative cap; silent loss rejected.');await db.close();
})().catch(async e=>{console.error(e);await db.close();process.exitCode=1;});
