// In-memory PostgreSQL only. No URL, credentials, or production connection path.
// Usage: PGLITE_MODULE=/absolute/path/to/@electric-sql/pglite node tests/final_revision_prune_db.cjs
const {PGlite}=require(process.env.PGLITE_MODULE || '@electric-sql/pglite');
const fs=require('node:fs');
const path=require('node:path');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const db=new PGlite();

const checksumSql=`
 select md5(string_agg(
  q.track_id||'|'||r.question_id::text||'|'||r.lesson||'|'||r.idea||'|'||
  r.difficulty||'|'||r.programmes::text||'|'||r.fingerprint||'|'||
  r.active::text||'|'||r.focus::text,
  ';' order by r.question_id
 )) state_md5
 from revision_items r join questions q on q.id=r.question_id where r.active
`;
const protectedTables=[
 'questions','question_keys','exams','revision_sessions','attempts',
 'attempt_answers','attempt_results','daily_quizzes','daily_progress','practice_notebook'
];
async function snapshot(){
 const result={};
 for(const table of protectedTables){
  result[table]=(await db.query(
   `select count(*)::int n,coalesce(md5(string_agg(to_jsonb(t)::text,';' order by to_jsonb(t)::text)),'') digest from ${table} t`
  )).rows[0];
 }
 return result;
}

async function main(){
 await db.exec(read('tests/final_revision_prune_fixture.sql'));
 const before=await snapshot();
 const fixtureChecksum=(await db.query(checksumSql)).rows[0].state_md5;
 let release=read('content-releases/20260930_final_revision_prune/apply.sql');
 const productionChecksum='e7baafb3a3ce792eb2f7401ea4efba1b';
 assert.equal(release.split(productionChecksum).length-1,1);
 release=release.replace(productionChecksum,fixtureChecksum);
 await db.exec(release);
 await db.exec(read('tests/final_revision_prune.sql'));
 const coverage=read('tests/final_revision_prune_coverage.sql');
 await db.exec(coverage);
 // Mutate individual slices: totals alone must not hide an idea loss.
 const victim=(await db.query(`select q.track_id,r.lesson,r.idea,r.difficulty
  from revision_items r join questions q on q.id=r.question_id
  where r.active order by q.id limit 1`)).rows[0];
 await db.exec('begin');
 await db.query(`update revision_items r set active=false from questions q
  where q.id=r.question_id and q.track_id=$1 and r.lesson=$2
  and lower(trim(r.idea))=lower(trim($3)) and r.difficulty=$4`,
  [victim.track_id,victim.lesson,victim.idea,victim.difficulty]);
 await assert.rejects(()=>db.exec(coverage),/without an explicit exclusion/);
 await db.exec('rollback');
 // Removing only a focused collection must fail even while All survives.
 const focused=(await db.query(`select question_id from revision_items
  where active and focus->'collections' ? 'unique' order by question_id limit 1`)).rows[0];
 await db.exec('begin');
 await db.query(`update revision_items set focus=jsonb_set(focus,'{collections}','[]')
  where active and (lesson,lower(trim(idea)),difficulty) in
   (select lesson,lower(trim(idea)),difficulty from revision_items where question_id=$1)`,
  [focused.question_id]);
 // Retained inactive metadata still establishes the intended Unique slice.
 await assert.rejects(()=>db.exec(coverage),/without an explicit exclusion/);
 await db.exec('rollback');
 await db.exec(coverage);
 // Explicit historical exclusions cannot discard a newly ready candidate.
 await db.exec('begin');
 await db.exec(`update revision_items r set fingerprint=revision_question_fingerprint(
  q.stem,q.choices,q.assets,k.correct,k.explanation)
  from questions q join question_keys k on k.question_id=q.id
  where r.question_id=q.id and r.idea='Common polynomial factor'`);
 await assert.rejects(()=>db.exec(coverage),/ready Final Revision idea/);
 await db.exec('rollback');
 assert.deepEqual(await snapshot(),before);
 assert.equal((await db.query('select count(*)::int n from revision_items')).rows[0].n,2427);
 assert.equal((await db.query('select count(*)::int n from revision_items where active')).rows[0].n,1344);
 await assert.rejects(()=>db.exec(release),/already applied; do not rerun/);
 console.log('PASS: in-memory representative pruning, preservation, collection coverage, and rerun rejection.');
 await db.close();
}
main().catch(async error=>{console.error(error);await db.close();process.exitCode=1;});
