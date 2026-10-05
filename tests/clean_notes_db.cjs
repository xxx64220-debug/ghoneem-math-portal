const {readFileSync}=require('node:fs');
const assert=require('node:assert/strict');
const {PGlite}=require(process.env.PGLITE_MODULE||'./june-review-runtime/node_modules/@electric-sql/pglite');
const source=readFileSync('content-releases/20261005_clean_notes/apply.sql','utf8');
const review=JSON.parse(readFileSync('content-releases/20261005_clean_notes/review.json','utf8'));
const hash="select md5(string_agg(md5(jsonb_build_array(to_jsonb(q),to_jsonb(k))::text),'' order by q.id)) as h from questions q left join question_keys k on k.question_id=q.id where q.track_id='est'";
async function setup(){
 const db=new PGlite();
 await db.exec(`create table questions(id uuid primary key,track_id text,topic text,difficulty text,type text,stem text,choices jsonb,assets jsonb,created_at timestamptz default now());
 create table question_keys(question_id uuid primary key references questions(id),correct jsonb,explanation text);
 create table audit_log(id bigserial primary key,action text,target_type text,target_id text,meta jsonb);
 create table exams(id uuid primary key,question_ids uuid[]);create table revision_items(question_id uuid primary key);
 insert into questions(id,track_id,stem,choices,assets) values('00000000-0000-0000-0000-000000000001','est','Existing question','[]','{}');
 insert into question_keys values('00000000-0000-0000-0000-000000000001','"A"','Existing explanation');`);
 for(const p of review.patches){const q=p.before_question,k=p.before_key;
  await db.query('insert into questions(id,track_id,topic,difficulty,type,stem,choices,assets,created_at) values($1,$2,$3,$4,$5,$6,$7,$8,$9)',[q.id,q.track_id,q.topic,q.difficulty,q.type,q.stem,JSON.stringify(q.choices),JSON.stringify(q.assets),q.created_at]);
  await db.query('insert into question_keys values($1,$2,$3)',[k.question_id,JSON.stringify(k.correct),k.explanation]);
 }return db;
}
async function packet(db,s=source){return s.replace(review.bank_hash,(await db.query(hash)).rows[0].h)}
async function reject(db,sql,pattern){await assert.rejects(db.exec(sql),pattern);await db.exec('rollback;');}
async function count(db,table){return (await db.query(`select count(*)::int as n from ${table}`)).rows[0].n}
(async()=>{
 let db=await setup();const keys=JSON.stringify((await db.query('select * from question_keys order by question_id')).rows);const sql=await packet(db);
 await db.exec(sql);assert.equal(await count(db,'questions'),17);assert.equal(await count(db,'question_keys'),17);
 assert.equal((await db.query("select count(*)::int as n from questions where assets ? 'release_hold_reason'")).rows[0].n,4);
 assert.equal((await db.query("select count(*)::int as n from questions where assets ? 'clean_source_evidence'")).rows[0].n,14);
 const ids=review.insert_questions.map(x=>"'"+x.id+"'").join(',');
 assert.equal(JSON.stringify((await db.query(`select * from question_keys where question_id not in (${ids}) order by question_id`)).rows),keys);
 for(const p of review.patches){const q=(await db.query('select * from questions where id=$1',[p.id])).rows[0];assert.equal(q.stem,p.stem);assert.deepEqual(q.choices,p.before_question.choices);assert.equal(q.topic,p.before_question.topic)}
 await reject(db,sql,/already applied/);await db.close();
 db=await setup();await reject(db,source,/bank changed/);await db.close();
 db=await setup();await db.query('insert into questions(id,track_id,stem,choices,assets) values($1,\'est\',\'Already present\',\'[]\',\'{}\')',[review.insert_questions[0].id]);
 await reject(db,await packet(db),/already present/);assert.equal(await count(db,'questions'),16);await db.close();
 db=await setup();await db.query('update questions set stem=$1 where id=\'00000000-0000-0000-0000-000000000001\'',[review.insert_questions[0].stem]);await reject(db,await packet(db),/Duplicate stem/);await db.close();
 db=await setup();const original=(await db.query(hash)).rows[0].h;
 const payload=JSON.parse(source.match(/\$payload\$([\s\S]*?)\$payload\$/)[1]);payload.inserts[1].explanation='';
 const bad=source.replace(/\$payload\$[\s\S]*?\$payload\$/,'$payload$'+JSON.stringify(payload)+'$payload$');
 await reject(db,await packet(db,bad),/Invalid candidate/);assert.equal((await db.query(hash)).rows[0].h,original);assert.equal(await count(db,'audit_log'),0);await db.close();
 db=await setup();await db.query('insert into exams values(\'00000000-0000-0000-0000-000000000002\',array[$1::uuid])',[review.patches[0].id]);await reject(db,await packet(db),/now used/);await db.close();
 db=await setup();await db.query('update questions set stem=\'Concurrent edit\' where id=$1',[review.patches[13].id]);await reject(db,await packet(db),/Concurrent imported record change/);assert.equal(await count(db,'audit_log'),0);await db.close();
 console.log('PASS: reconciliation, two inserts, four duplicate holds, keys, replay, stale-bank, duplicates, atomicity and assessment-use guards');
})().catch(e=>{console.error(e.message);process.exit(1)});
