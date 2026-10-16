// Isolated PostgreSQL WASM, synthetic fixtures only; no production connection.
const {PGlite}=require('./june-review-runtime/node_modules/@electric-sql/pglite');
const fs=require('node:fs'),assert=require('node:assert/strict');
const db=new PGlite(),read=f=>fs.readFileSync(f,'utf8');
const scalar=async(sql,args=[])=>Object.values((await db.query(sql,args)).rows[0])[0];
async function main(){
 for(const f of ['tests/00_shim.sql','supabase/migrations/001_schema.sql','supabase/migrations/002_functions.sql','supabase/migrations/003_policies.sql','supabase/migrations/004_seed.sql','supabase/migrations/005_function_hardening.sql'])await db.exec(read(f).replace(/create extension if not exists pgcrypto;/g,''));
 await db.exec('alter table exams add column is_full_length boolean default false,add column assessment_type text default \'quiz\';');
 for(const f of ['supabase/sql/daily_challenge.sql','supabase/migrations/20260920_ranked_question_success.sql','supabase/sql/portal_access.sql','supabase/sql/portal_scope.sql','supabase/sql/portal_upgrade.sql','supabase/sql/fair_exam_keys.sql','supabase/sql/hardest_question_loading.sql','supabase/sql/hardest_cycles.sql'])await db.exec(read(f));
 // Includes the existing metric and RLS regression checks; keep fixtures in transaction.
 await db.exec(read('tests/hardest_questions.sql').replace(/rollback;\s*$/,''));
 const uid=await scalar("select id from hq_ids where name='admin'");
 const student=await scalar("select id from hq_ids where name='student'");
 await db.query('select public.test_login($1)',[uid]);
 const initial=await db.query("select * from hardest_current_questions where track_id='sat' order by rank");
 assert.equal(initial.rows.length,2);
 const archived=await scalar("select staff_archive_hardest_cycle('sat','Trial one')");
 assert.equal(archived.questions,2);
 assert.equal(await scalar("select count(*)::int from hardest_current_questions where track_id='sat'"),0);
 assert.equal(await scalar("select count(*)::int from hardest_current_questions where track_id='est2'"),2);
 assert.deepEqual((await db.query('select rank,track_id,lesson,question_id,stem,sources,answered_by,got_it_right,got_it_wrong,percent_correct from hardest_archived_questions where cycle_id=$1 order by rank',[archived.archived_cycle])).rows,initial.rows);
 // Future retake enters only the new cycle; older unfinished attempts remain out.
 await db.exec('reset role');
 const ex=await scalar("select exam from hq_questions where track='sat'");
 const q=await scalar("select q1 from hq_questions where track='sat'");
 const a=await scalar("insert into attempts(user_id,exam_id,attempt_no,shuffle_seed,status,deadline_at,started_at) values($1,$2,2,9,'graded',clock_timestamp(),clock_timestamp()) returning id",[student,ex]);
 await db.query('insert into attempt_results(attempt_id,question_id,is_correct) values($1,$2,true)',[a,q]);
 await db.query("update questions set stem='Changed after archive',assets='{\"figure\":\"new\"}' where id=$1",[q]);
 await db.query('select public.test_login($1)',[uid]);
 assert.equal(await scalar("select answered_by from hardest_current_questions where question_id=$1",[q]),1);
 assert.equal(await scalar("select question_snapshot->>'stem' from hardest_cycle_questions where cycle_id=$1 and question_id=$2",[archived.archived_cycle,q]),'Two plus two?');
 await db.exec('savepoint retry');
 await assert.rejects(()=>db.query("select staff_archive_hardest_cycle('sat','duplicate',null)"),/cycle_changed_refresh/);await db.exec('rollback to savepoint retry');
 const second=await scalar("select staff_archive_hardest_cycle('sat','Trial two',$1)",[archived.new_cycle]);
 assert.equal(second.questions,1);
 assert.equal(await scalar("select count(*)::int from hardest_current_questions where track_id='sat'"),0);
 // Completed daily quizzes enter the new cycle without altering older progress.
 await db.exec('reset role');
 await db.query("update daily_progress set quiz_completed_at=clock_timestamp() where track_id='sat' and user_id=$1 and quiz_completed_at is not null",[student]);
 await db.query('select public.test_login($1)',[uid]);
 assert.equal(await scalar("select answered_by from hardest_current_questions where question_id=$1",[q]),1);
 for(const role of ['student','instructor','suspended']){
  await db.exec('reset role');await db.exec('savepoint permission');
  await db.query('select public.test_login((select id from hq_ids where name=$1))',[role]);
  assert.equal(await scalar('select count(*)::int from hardest_archived_questions'),0);
  await assert.rejects(()=>db.query("select staff_archive_hardest_cycle('sat','forbidden',$1)",[second.new_cycle]),/admin_required/);
  await db.exec('rollback to savepoint permission');
 }
 await db.exec('reset role');
 assert.equal(await scalar("select has_function_privilege('anon','public.staff_archive_hardest_cycle(text,text,uuid)','execute')"),false);
 assert.equal(await scalar("select has_table_privilege('authenticated','public.hardest_cycle_questions','delete')"),false);
 assert.equal(await scalar('select count(*)::int from attempts'),7);
 await db.exec('rollback');console.log('PASS: archive equality, immutable question snapshots, fresh attempts/daily cycles, retries, track isolation, RLS and history preservation.');
 await db.close();
}
main().catch(async e=>{console.error(e.stack);await db.close();process.exitCode=1;});
