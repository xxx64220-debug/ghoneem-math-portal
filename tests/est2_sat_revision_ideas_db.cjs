// In-memory PostgreSQL only. No URL, credentials, or production connection path.
// Usage: PGLITE_MODULE=/absolute/path/to/@electric-sql/pglite node tests/est2_sat_revision_ideas_db.cjs
const {PGlite}=require(process.env.PGLITE_MODULE || '@electric-sql/pglite');
const fs=require('node:fs');
const path=require('node:path');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const db=new PGlite();

async function main(){
 await db.exec(`
  create table tracks(id text primary key,name text not null);
  create table questions(id uuid primary key,track_id text not null references tracks(id),topic text not null,difficulty text not null,type text not null,stem text not null,choices jsonb not null,assets jsonb not null);
  create table question_keys(question_id uuid primary key references questions(id),correct jsonb not null,explanation text not null);
  create table revision_items(question_id uuid primary key references questions(id),lesson text not null,idea text not null,difficulty text not null,programmes text[] not null,fingerprint text not null,active boolean not null default true);
  create table audit_log(id bigserial primary key,action text not null,target_type text,target_id text,meta jsonb not null default '{}',at timestamptz not null default now());
 `);
 await db.exec(read('tests/est2_sat_revision_ideas_fixture.sql'));
 const questionCount=(await db.query('select count(*)::int n from questions')).rows[0].n;
 const keyCount=(await db.query('select count(*)::int n from question_keys')).rows[0].n;
 await db.exec(read('content-releases/20260929_est2_sat_revision_ideas/apply.sql'));
 await db.exec(read('tests/est2_sat_revision_ideas.sql'));
 assert.equal((await db.query('select count(*)::int n from questions')).rows[0].n,questionCount);
 assert.equal((await db.query('select count(*)::int n from question_keys')).rows[0].n,keyCount);
 await assert.rejects(()=>db.exec(read('content-releases/20260929_est2_sat_revision_ideas/apply.sql')),/already applied; do not rerun/);
 await db.exec('rollback');
 assert.equal((await db.query("select count(*)::int n from audit_log where action='revision.est2_sat_idea_expansion.20260929'")).rows[0].n,1);
 console.log('PASS: in-memory PostgreSQL SAT + EST II apply, preservation, track scope and rerun rejection.');
 await db.close();
}
main().catch(async error=>{console.error(error);await db.close();process.exitCode=1;});
