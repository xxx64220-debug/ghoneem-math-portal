// Isolated PostgreSQL regression; never connects to production.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {PGlite}=require(process.env.PGLITE_MODULE||'@electric-sql/pglite');
const dir=path.resolve(__dirname,'../content-releases/20260930_est_remaining_audit');
const rows=JSON.parse(fs.readFileSync(path.join(dir,'reviewed-prune-reconciliation-input.json')));
const db=new PGlite();
(async()=>{
 await db.exec(`create table questions(id uuid primary key,track_id text,difficulty text,stem text,choices jsonb,assets jsonb);
 create table question_keys(question_id uuid primary key,correct jsonb,explanation text);
 create table revision_items(question_id uuid primary key,lesson text,idea text,difficulty text,programmes text[],focus jsonb,active boolean,fingerprint text);
 create table exams(id uuid primary key,is_published boolean,question_ids uuid[]);
 create table audit_log(action text,target_type text,target_id text,meta jsonb);`);
 let sql=fs.readFileSync(path.join(dir,'reviewed-prune-reconciliation.sql'),'utf8');
 for(const q of rows){
  await db.query('insert into questions values($1,$2,$3,$4,$5,$6)',[q.id,'est','medium',q.stem,JSON.stringify(q.choices),JSON.stringify(q.assets)]);
  await db.query('insert into question_keys values($1,$2,$3)',[q.id,JSON.stringify(q.correct),q.explanation]);
  await db.query('insert into revision_items values($1,$2,$3,$4,$5,$6,false,$7)',[q.id,q.lesson,q.idea,q.revision_difficulty,q.programmes,JSON.stringify(q.focus),'old-stale-certificate']);
  const a=(await db.query('select md5(to_jsonb(q)::text) q_digest,md5(to_jsonb(k)::text) key_digest from questions q join question_keys k on k.question_id=q.id where q.id=$1',[q.id])).rows[0];
  sql=sql.replaceAll(q.q_digest,a.q_digest).replaceAll(q.key_digest,a.key_digest);
 }
 await db.exec(`create function revision_question_fingerprint(text,jsonb,jsonb,jsonb,text) returns text language sql immutable as $$select md5($1||$2::text||$3::text||$4::text||$5)$$;
 insert into questions values('fa4af000-7c2b-5a7c-a0f2-222016a9d1e9','est','medium','bad source','[]','{"release_hold_reason":"Ambiguous source"}');
 insert into revision_items values('fa4af000-7c2b-5a7c-a0f2-222016a9d1e9','Systems of equations','No-solution conditions','medium',array['est'],'{"collections":["must_know"]}',false,'stale');`);
 const keys=(await db.query('select * from question_keys order by question_id')).rows;
 const metadata=(await db.query('select question_id,lesson,idea,difficulty,programmes,focus from revision_items order by question_id')).rows;
 await db.exec(sql);assert.deepEqual((await db.query('select * from question_keys order by question_id')).rows,keys);assert.deepEqual((await db.query('select question_id,lesson,idea,difficulty,programmes,focus from revision_items order by question_id')).rows,metadata);
 const live=(await db.query('select * from revision_items where active')).rows;assert.equal(live.length,3);const unique=live.find(q=>q.question_id.startsWith('afee'));assert.equal(unique.difficulty,'hard');assert.deepEqual(unique.focus.collections,['unique']);assert.deepEqual(unique.programmes,['est']);
 assert.equal(9/8*4/3+1,2.5);assert.equal((25+10-5)/50/2,0.3);assert.equal(-((0-1)**2),-1);
 const coverage=async()=>assert.equal((await db.query('select count(*)::int n from revision_items where active')).rows[0].n,3);await coverage();await db.query('update revision_items set active=false where question_id=$1',[rows[0].id]);await assert.rejects(coverage);await db.query('update revision_items set active=true where question_id=$1',[rows[0].id]);
 await assert.rejects(()=>db.exec(sql),/already applied/);await db.exec('rollback');console.log('PASS: independently reconciled sources restore exact lesson/idea/difficulty/focus coverage; metadata and keys preserved; silent loss rejected.');await db.close();
})().catch(async e=>{console.error(e);await db.close();process.exitCode=1;});
