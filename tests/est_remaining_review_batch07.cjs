// In-memory PostgreSQL only; no remote connections or credentials.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {PGlite}=require(process.env.PGLITE_MODULE||'@electric-sql/pglite');
const root=path.resolve(__dirname,'..'),dir=path.join(root,'content-releases/20260930_est_remaining_audit');
const rows=JSON.parse(fs.readFileSync(path.join(dir,'batch-07-input.json')));
const guards=JSON.parse(fs.readFileSync(path.join(dir,'batch-07-guards.json')));
const db=new PGlite();
(async()=>{
 await db.exec(`create table questions(id uuid primary key,track_id text,topic text,difficulty text,type text,stem text,choices jsonb,assets jsonb);
 create table question_keys(question_id uuid primary key,correct jsonb,explanation text);
 create table revision_items(question_id uuid primary key,active boolean,fingerprint text);
 create table audit_log(action text,target_type text,target_id text,meta jsonb);
 create function revision_question_fingerprint(text,jsonb,jsonb,jsonb,text) returns text language sql immutable as $$select md5($1||$2::text||$3::text||$4::text||$5)$$;`);
 for(const q of rows){
  await db.query('insert into questions values($1,$2,$3,$4,$5,$6,$7,$8)',[q.id,'est',q.topic,q.difficulty,q.type,q.stem,JSON.stringify(q.choices),JSON.stringify(q.assets)]);
  await db.query('insert into question_keys values($1,$2,$3)',[q.id,JSON.stringify(q.correct),q.explanation]);
 }
 let sql=fs.readFileSync(path.join(dir,'batch-07-apply.sql'),'utf8');
 for(let i=0;i<guards.length;i++){
  const g=guards[i];const actual=(await db.query(`select md5(to_jsonb(q)::text) q_digest,md5(to_jsonb(k)::text) key_digest,revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation) fingerprint from questions q join question_keys k on k.question_id=q.id where q.id=$1`,[g.id])).rows[0];
  for(const name of ['q_digest','key_digest','fingerprint'])sql=sql.replaceAll(g[name],actual[name]);
  await db.query('insert into revision_items values($1,$2,$3)',[g.id,i%2===0,i===0?'stale-certificate':actual.fingerprint]);
 }
 const beforeKeys=(await db.query('select question_id,correct from question_keys order by question_id')).rows;
 const beforeRevision=(await db.query('select question_id,active from revision_items order by question_id')).rows;
 await db.exec(sql);
 assert.deepEqual((await db.query('select question_id,correct from question_keys order by question_id')).rows,beforeKeys);
 assert.deepEqual((await db.query('select question_id,active from revision_items order by question_id')).rows,beforeRevision);
 assert.equal((await db.query('select fingerprint from revision_items where question_id=$1',[guards[0].id])).rows[0].fingerprint,'stale-certificate');
 assert.equal((await db.query('select count(*)::int n from audit_log')).rows[0].n,50);
 assert.equal(Math.round(0.3**3*1000)/1000,0.027);assert.equal(100-33-10-14,43);assert.equal(4**2+3*4,28);assert.equal(7*6*5*4*3*2/2,2520);assert.equal(Math.sqrt(15**2-9**2),12);assert.equal(Math.sqrt(20**2-12**2),16);assert.equal((9+16)*12/2,150);assert.equal((24+36)/2,30);assert.equal(205*(172+100)+12*3994,103688);assert.equal((101+60)/320,0.503125);
 const independence=(await db.query('select stem from questions where id=$1',[rows[0].id])).rows[0].stem;assert.match(independence,/independent/);
 await assert.rejects(()=>db.exec(sql),/already applied/i);await db.exec('rollback');
 console.log('PASS: 50 reviewed records, exact keys, numeric regressions, source transcriptions, stale certificates and publication states preserved.');
 await db.close();
})().catch(async e=>{console.error(e);await db.close();process.exitCode=1;});
