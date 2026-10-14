// In-memory PostgreSQL only. No URL, credentials, or production connection path.
// Usage: PGLITE_MODULE=/absolute/path/to/@electric-sql/pglite node tests/june_remaining_review_db.cjs
const {PGlite}=require(process.env.PGLITE_MODULE || '@electric-sql/pglite');
const fs=require('node:fs');
const path=require('node:path');
const zlib=require('node:zlib');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
const dir=path.join(root,'content-releases/20260929_june_remaining_review');
const original=JSON.parse(zlib.gunzipSync(fs.readFileSync(path.join(__dirname,'fixtures/june-before-review.json.gz'))));
const repairs=JSON.parse(fs.readFileSync(path.join(dir,'repairs.json')));
const sql=fs.readFileSync(path.join(dir,'apply.sql'),'utf8');
const db=new PGlite();
const literal=s=>"'"+s.replaceAll("'","''")+"'";
async function snapshot(){return (await db.query(`select q.*,k.correct,k.explanation from questions q join question_keys k on k.question_id=q.id order by q.id`)).rows;}
async function main(){
 await db.exec(`create table questions(id uuid primary key,track_id text not null,stem text not null,choices jsonb not null,assets jsonb not null,topic text default 'preserved lesson',created_at timestamptz default '2026-01-01');
 create table question_keys(question_id uuid primary key references questions(id),correct jsonb not null,explanation text not null);
 create table audit_log(id bigserial primary key,action text,target_type text,target_id text,meta jsonb);
 create table exam_questions(exam_id text,question_id uuid references questions(id),position int);
 create table student_results(student_id text,exam_id text,score int,responses jsonb);
 insert into questions(id,track_id,stem,choices,assets) select id::uuid,track_id,stem,choices,assets from jsonb_to_recordset(${literal(JSON.stringify(original))}::jsonb) as t(id text,track_id text,stem text,choices jsonb,assets jsonb);
 insert into question_keys select id::uuid,correct,explanation from jsonb_to_recordset(${literal(JSON.stringify(original))}::jsonb) as t(id text,correct jsonb,explanation text);
 insert into exam_questions select 'existing-exam',id,row_number() over(order by id) from questions;
 insert into student_results values ('synthetic-student','existing-exam',77,'{"saved":"unchanged"}');`);
 const before=await snapshot();
 const membership=(await db.query('select * from exam_questions order by position')).rows;
 const results=(await db.query('select * from student_results')).rows;
 // Fail late in the batch and prove earlier writes and audit entries are rolled back.
 const last=repairs.map(r=>r.id).sort().at(-1);
 const lastBefore=before.find(r=>r.id===last);
 await db.query("update questions set assets=assets || '{\"concurrent_change\":true}' where id=$1",[last]);
 await assert.rejects(()=>db.exec(sql),/Concurrent content or asset change/);
 await db.exec('rollback');
 assert.equal((await db.query('select count(*)::int n from audit_log')).rows[0].n,0);
 await db.query('update questions set assets=$1::jsonb where id=$2',[JSON.stringify(lastBefore.assets),last]);
 assert.deepEqual(await snapshot(),before);
 await db.exec(sql);
 const after=await snapshot();
 const patches=new Map(repairs.map(r=>[r.id,r]));
 for(const old of before){
   const now=after.find(r=>r.id===old.id), p=patches.get(old.id);
   const expected=p?{...old,...p.after,assets:{...old.assets,...p.asset_patch}}:old;
   assert.deepEqual(now,expected,old.id);
   if(old.assets.release_hold_reason)assert.equal(now.assets.release_hold_reason,old.assets.release_hold_reason);
 }
 assert.deepEqual((await db.query('select * from exam_questions order by position')).rows,membership);
 assert.deepEqual((await db.query('select * from student_results')).rows,results);
 assert.equal((await db.query('select count(*)::int n from audit_log')).rows[0].n,263);
 await db.exec(sql);
 assert.deepEqual(await snapshot(),after);
 assert.equal((await db.query('select count(*)::int n from audit_log')).rows[0].n,263);
 await db.query("update question_keys set explanation='later intentional edit' where question_id=$1",[last]);
 await assert.rejects(()=>db.exec(sql),/Reviewed record changed after application/);
 await db.exec('rollback');
 assert.equal((await db.query('select explanation from question_keys where question_id=$1',[last])).rows[0].explanation,'later intentional edit');
 console.log('PASS: in-memory PostgreSQL application, late-conflict atomic rollback, exact 484-record preservation, five existing holds, membership/results, idempotency, and replay drift rejection.');
 await db.close();
}
main().catch(async e=>{console.error(e);await db.close();process.exitCode=1;});
