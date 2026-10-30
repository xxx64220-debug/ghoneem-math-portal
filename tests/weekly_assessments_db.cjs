// Execute the real scheduler SQL and captured production access/timer functions
// in disposable PostgreSQL. Only now() is redirected to a controlled test clock.
const {PGlite}=require(process.env.PGLITE_MODULE||'./june-review-runtime/node_modules/@electric-sql/pglite');
const fs=require('node:fs'),assert=require('node:assert/strict');
const db=new PGlite(),read=f=>fs.readFileSync(f,'utf8'),id=n=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
let checks=0;const eq=(a,b,m)=>{assert.deepEqual(a,b,m);checks++;},ok=(v,m)=>{assert(v,m);checks++;};
const scalar=async(q,args=[])=>Object.values((await db.query(q,args)).rows[0])[0];
const clock=async t=>db.query("select set_config('test.clock',$1,false)",[t]);
const timed=s=>s.replace(/\bnow\(\)/g,'public.weekly_test_now()');
const run=()=>scalar('select portal_private.run_weekly_assessments()');
const prep=(d='2026-11-03')=>scalar('select portal_private.prepare_weekly_assessment($1,$2)',[id(10),d]);
async function main(){
 for(const f of ['tests/00_shim.sql','supabase/migrations/001_schema.sql','supabase/migrations/002_functions.sql','supabase/migrations/003_policies.sql','supabase/migrations/005_function_hardening.sql'])
  await db.exec(read(f).replace(/create extension if not exists pgcrypto;/g,''));
 await db.exec(`
 insert into tracks(id,name) values('sat','SAT'),('est','EST');
 create function public.weekly_test_now() returns timestamptz language sql stable as $$select current_setting('test.clock')::timestamptz$$;
 alter table exams add column is_full_length boolean default false,add column assessment_type text default 'lesson_exam';
 alter table enrollments add column starts_at timestamptz,add column ends_at timestamptz;
 create table public.question_catalogue(question_id uuid primary key,reserve boolean default false);
 create table public.daily_quizzes(track_id text,day date,question_ids uuid[]);
 create table public.daily_group_quizzes(group_id uuid,day date,question_ids uuid[]);
 create table public.daily_progress(user_id uuid,track_id text,day date,quiz_group_id uuid,quiz_completed_at timestamptz);
 create function portal_private.attempt_course_access(uuid,uuid,boolean) returns boolean language sql as $$select false$$;
 create unique index assignments_unique_exam_target_idx on assignments(exam_id,group_id,user_id) nulls not distinct;
 `);
 await clock('2026-10-30T10:00:00Z');
 await db.exec(timed(read('tests/fixtures/weekly_assessment_live_dependencies.sql')));
 await db.exec(timed(read('supabase/sql/weekly_assessments.sql')));
 for(const n of [1,2]){
  await db.query('insert into auth.users(id,email) values($1,$2)',[id(n),n+'@example.test']);
  await db.query("insert into profiles(id,role) values($1,'student')",[id(n)]);
  await db.query("insert into enrollments(user_id,track_id) values($1,'est')",[id(n)]);
 }
 await db.query("insert into groups(id,track_id,name) values($1,'est','Synthetic Alex')",[id(3)]);
 await db.query('insert into group_members values($1,$2)',[id(3),id(1)]);
 const topics=['Algebraic expressions and equations','Systems of equations','Linear functions and slope','Inequalities and absolute value','Quadratics and polynomials','Functions and transformations','Exponents, radicals and growth'];
 await db.query(`insert into portal_private.weekly_assessment_schedules(id,code,group_id,track_id,title,starts_on,topics)
 values($1,'alex-test',$2,'est','Alex weekly algebra','2026-11-03',$3)`,[id(10),id(3),topics]);
 eq((await prep()).status,'disabled');
 await db.exec('update portal_private.weekly_assessment_schedules set enabled=true');
 eq((await prep()).status,'blocked');eq(await scalar('select count(*)::int from exams'),0,'no partial assessment on insufficient pool');
 let n=100;
 // Different conceptual stems; no number-only clone templates.
 for(const [ti,topic] of topics.entries()) for(let j=0;j<20;j++){
  const qid=id(n++),word=String.fromCharCode(97+j)+String.fromCharCode(97+ti);
  await db.query(`insert into questions(id,track_id,topic,difficulty,stem,choices,assets)
   values($1,'est',$2,$3,$4,'[{"key":"A","text":"one"},{"key":"B","text":"two"},{"key":"C","text":"three"},{"key":"D","text":"four"}]',$5)`,
   [qid,topic,j%3===0?'easy':'medium',`Find the ${word} property for topic ${topic}.`,JSON.stringify({verified_release:'fixture',answer_review_status:'independently_solved',lesson_subtopic:word})]);
  await db.query('insert into question_keys values($1,\'"A"\',\'Fixture independently checked explanation\')',[qid]);
 }
 // One disqualifier of each kind; none may escape into a quiz.
 await db.query("update questions set difficulty='hard' where id=$1",[id(100)]);
 await db.query("update questions set assets=assets||'{\"release_hold_reason\":\"hold\"}' where id=$1",[id(101)]);
 await db.query('delete from question_keys where question_id=$1',[id(102)]);
 await db.query("update question_keys set correct='\"Z\"' where question_id=$1",[id(103)]);
 await db.query("update questions set assets=assets-'answer_review_status' where id=$1",[id(104)]);
 await db.query("update questions set assets=assets||'{\"duplicate_of\":\"known duplicate\"}' where id=$1",[id(105)]);
 await db.query('insert into question_catalogue values($1,true)',[id(106)]);
 await db.query("update questions set assets=assets||'{\"figure_required\":true}' where id=$1",[id(107)]);
 await db.query("update questions set track_id='sat' where id=$1",[id(108)]);
 await db.query("insert into exams(id,track_id,title,duration_seconds,question_ids,is_published,assessment_type) values($1,'est','Historical quiz',1200,$2,true,'quiz')",[id(20),[id(109)]]);
 await db.query("insert into attempts(id,user_id,exam_id,attempt_no,shuffle_seed,status,deadline_at,score,total) values($1,$2,$3,1,1,'graded',now(),1,1)",[id(21),id(1),id(20)]);
 await db.query("update questions set stem=(select stem from questions where id=$1) where id=$2",[id(109),id(110)]);
 await db.query("insert into daily_group_quizzes values($1,'2026-10-29',$2)",[id(3),[id(111)]]);
 await db.query("insert into daily_progress values($1,'est','2026-10-29',$2,now())",[id(1),id(3)]);
 const snapshot=()=>scalar("select jsonb_build_object('history',(select to_jsonb(a) from attempts a where id='"+id(21)+"'),'daily',(select jsonb_agg(to_jsonb(d)) from daily_progress d))");
 const before=await snapshot();
 const candidates=await scalar('select array_agg(question_id::text) from portal_private.weekly_assessment_candidates($1)',[id(10)]);
 for(let k=100;k<=111;k++)ok(!candidates.includes(id(k)),'excludes disqualified '+k);
 await assert.rejects(()=>prep('2026-11-04'),/invalid_weekly_release_date/);checks++;
 await assert.rejects(()=>prep('2026-11-17'),/weekly_release_too_far_ahead/);checks++;
 // App roles cannot invoke the worker, inspect config, or enable a schedule.
 for(const role of ['anon','authenticated','service_role']){
  await db.exec('set role '+role);
  await assert.rejects(run,/permission denied/);checks++;
  await assert.rejects(()=>scalar('select count(*) from portal_private.weekly_assessment_schedules'),/permission denied/);checks++;
  await db.exec('reset role');
 }
 const first=await prep();eq(first.status,'created');
 const exam=await scalar('select to_jsonb(e) from exams e where id=$1',[first.exam_id]);
 eq(exam.duration_seconds,1200);eq(exam.assessment_type,'quiz');eq(exam.question_ids.length,10);
 eq(new Date(first.open_at).toISOString(),'2026-11-03T11:10:00.000Z','Cairo winter conversion');
 eq(new Date(first.close_at).toISOString(),'2026-11-03T11:30:00.000Z');
 const selection=await scalar('select selection from portal_private.weekly_assessment_runs where schedule_id=$1',[id(10)]);
 eq(new Set(selection.map(x=>x.concept)).size,10);eq(new Set(selection.map(x=>x.family_key)).size,10);
 ok(Object.values(selection.reduce((a,x)=>(a[x.topic]=(a[x.topic]||0)+1,a),{})).every(x=>x<=2));
 eq((await prep()).exam_id,first.exam_id);eq((await run())[0].status,'existing');
 eq(await scalar('select count(*)::int from exams'),2,'retries create no copies');
 await assert.rejects(()=>db.query("insert into portal_private.weekly_assessment_runs(schedule_id,release_date,status) values($1,'2026-11-03','blocked')",[id(10)]),/duplicate key/);checks++;
 // Test actual production window lookup and start/timer behavior.
 const access=()=>scalar('select student_assignment_for($1,$2)',[first.exam_id,id(1)]);
 await clock('2026-11-03T11:09:59Z');eq(await access(),null,'not available early');
 await assert.rejects(()=>scalar('select portal_start_attempt($1,$2,false)',[first.exam_id,id(1)]),/not_assigned_or_window_closed/);checks++;
 await clock('2026-11-03T11:10:00Z');eq(await access(),first.assignment_id,'available at exact boundary');
 eq(await scalar('select student_assignment_for($1,$2)',[first.exam_id,id(2)]),null,'other student excluded');
 await assert.rejects(()=>scalar('select portal_start_attempt($1,$2,true)',[first.exam_id,id(1)]),/untimed_lessons_only/);checks++;
 const attempt=await scalar('select to_jsonb(portal_start_attempt($1,$2,false))',[first.exam_id,id(1)]);
 eq(new Date(attempt.deadline_at).getTime()-Date.parse('2026-11-03T11:10:00Z'),1200000,'20 minute server deadline');
 eq((await scalar('select to_jsonb(portal_start_attempt($1,$2,false))',[first.exam_id,id(1)])).id,attempt.id,'repeat start resumes same attempt');
 await db.query("update attempts set status='graded',score=6,total=10 where id=$1",[attempt.id]);
 await assert.rejects(()=>scalar('select portal_start_attempt($1,$2,false)',[first.exam_id,id(1)]),/attempt_limit_reached/);checks++;
 await clock('2026-11-03T11:30:01Z');eq(await access(),null,'new starts closed after session time');
 // Next week gets a new quiz, new questions and least-used concepts.
 const second=(await run())[0];eq(second.status,'created');ok(second.exam_id!==first.exam_id);
 const q2=await scalar('select question_ids from exams where id=$1',[second.exam_id]);ok(!q2.some(q=>exam.question_ids.includes(q)));
 const s2=await scalar('select selection from portal_private.weekly_assessment_runs where exam_id=$1',[second.exam_id]);
 ok(!s2.some(x=>selection.some(y=>y.concept===x.concept)),'rotates concepts while unused concepts remain');
 eq(await snapshot(),before,'old grades and Daily Quiz data unchanged');
 // Manual edits are not overwritten or duplicated.
 await db.query('update exams set duration_seconds=1300 where id=$1',[second.exam_id]);
 eq((await run())[0].status,'needs_review');eq(await scalar('select count(*)::int from exams'),3);
 await db.query('update exams set duration_seconds=1200 where id=$1',[second.exam_id]);
 await db.exec('update portal_private.weekly_assessment_schedules set enabled=false');eq(await run(),[]);
 await db.exec('update portal_private.weekly_assessment_schedules set enabled=true');
 // Late catch-up never creates a missed old assessment.
 await clock('2026-11-17T12:00:00Z');eq((await prep('2026-11-17')).status,'missed');
 await clock('2026-11-16T08:00:00Z');
 await db.exec(`create function public.reject_weekly_assignment() returns trigger language plpgsql as $$begin raise exception 'synthetic_assignment_failure';end$$;
 create trigger reject_weekly_assignment before insert on assignments for each row execute function public.reject_weekly_assignment();`);
 eq((await run())[0].status,'error');eq(await scalar('select count(*)::int from exams'),3,'late failure rolls back exam insert');
 await db.exec('drop trigger reject_weekly_assignment on assignments');
 eq((await run())[0].status,'created','retry succeeds after failure');
 // Cairo follows local wall time across daylight saving, not a fixed UTC offset.
 await clock('2027-05-03T08:00:00Z');const summer=(await run())[0];
 eq(new Date(summer.open_at).toISOString(),'2027-05-04T10:10:00.000Z','Cairo summer conversion');
 eq(await snapshot(),before);
 console.log('PASS: '+checks+' weekly scheduler PostgreSQL assertions (eligibility, authorization, duplicate guards, atomic rollback, rotation, Cairo DST, release windows, timers, history).');
 await db.close();
}
main().catch(async e=>{console.error(e.stack||e);await db.close();process.exitCode=1;});
