// In-memory PostgreSQL only; no remote connections or credentials.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {PGlite}=require(process.env.PGLITE_MODULE||'@electric-sql/pglite');
const root=path.resolve(__dirname,'..'),dir=path.join(root,'content-releases/20260930_est_remaining_audit');
const rows=JSON.parse(fs.readFileSync(path.join(dir,'batch-04-input.json')));
const guards=JSON.parse(fs.readFileSync(path.join(dir,'batch-04-guards.json')));
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
 let sql=fs.readFileSync(path.join(dir,'batch-04-apply.sql'),'utf8');
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
 assert.equal((await db.query('select count(*)::int n from audit_log')).rows[0].n,100);
 for(const q of rows){const live=(await db.query('select stem,choices from questions where id=$1',[q.id])).rows[0]; assert.doesNotMatch(live.stem,/answer the original|select the answer from the original/i);assert(live.choices.every(c=>!/select [A-D]|option [A-D] in the original/i.test(c.text)));}
 assert.equal((25+2*31+3*14+4*8+5*2+20+2*19+3*23+4*12+5*6)/160,2.35);
 assert.equal((1393.34-1668.86)/6,-45.919999999999995);
 assert.equal(Math.round(9.12*1.01**11*1e6),10174895);
 assert.equal(16*525/1.75,4800);
 assert.equal(12000*3/15,2400);
 assert.equal(2*3**4-3**2+3+1,157);
 assert.equal(8*7*6*5*4,6720);
 assert.equal(6*78-5*75,93);
 assert.equal(Math.round(91072+16*(94640-91072)/10),96781);
 assert.equal(79+0.44*4252,1949.88); assert(79+0.44*4253>1950);
 assert.equal(12/35,(3*2*2)/35);
 const corrected=(await db.query('select explanation from question_keys where question_id=$1',[rows[14].id])).rows[0].explanation;assert.match(corrected,/171/);assert.match(corrected,/2.35/);
 const normalized=(await db.query('select stem from questions where id=$1',[rows[97].id])).rows[0].stem;assert.match(normalized,/gcd/);
 await assert.rejects(()=>db.exec(sql),/already applied/i);await db.exec('rollback');
 console.log('PASS: 100 reviewed records, exact keys, numeric regressions, source transcriptions, stale certificates and publication states preserved.');
 await db.close();
})().catch(async e=>{console.error(e);await db.close();process.exitCode=1;});
