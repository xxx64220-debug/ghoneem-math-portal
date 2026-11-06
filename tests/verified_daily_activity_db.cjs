// Isolated PostgreSQL with synthetic students; never contacts production.
// Reuse the existing synthetic group-isolation fixture; no production connections.
const {PGlite}=require('./june-review-runtime/node_modules/@electric-sql/pglite');
const fs=require('node:fs'),assert=require('node:assert/strict');const db=new PGlite();
const read=f=>fs.readFileSync(f,'utf8'),id=n=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
const admin=id(1),teacher=id(2),student=id(3),outsider=id(4),otherTeacher=id(5);const tracks=['sat','est','est2','est_eng'];
const scalar=async(s,a=[])=>Object.values((await db.query(s,a)).rows[0])[0];
const login=async u=>db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:u})]);
let gates=0;const ok=(v,m)=>{assert(v,m);gates++;};
async function main(){
 for(const f of ['tests/00_shim.sql','supabase/migrations/001_schema.sql','supabase/migrations/002_functions.sql','supabase/migrations/003_policies.sql','supabase/migrations/004_seed.sql','supabase/migrations/005_function_hardening.sql'])await db.exec(read(f).replace(/create extension if not exists pgcrypto;/g,''));
 await db.exec("alter table exams add column is_full_length boolean default false,add column assessment_type text default 'lesson_exam',add column exam_set_code text,add column module_number integer,add column module_count integer;");
 for(const f of ['supabase/sql/daily_challenge.sql','supabase/migrations/20260920_ranked_question_success.sql','supabase/sql/portal_access.sql','supabase/sql/portal_scope.sql','supabase/sql/portal_upgrade.sql','supabase/sql/fair_exam_keys.sql','supabase/sql/hardest_question_loading.sql','supabase/sql/hardest_cycles.sql','supabase/sql/question_eligibility_core.sql'])await db.exec(read(f));
 await db.exec(`create table portal_track_controls(track_id text primary key,daily_mode text default 'random',daily_lessons text[] default '{}',daily_question_ids uuid[] default '{}',revision_visible boolean default true);
 create table portal_reports(id uuid default gen_random_uuid(),user_id uuid,track_id text,request_id uuid,kind text,question_id uuid,screen text,message text,created_at timestamptz default now(),unique(user_id,request_id));
 create table practice_drills(id uuid default gen_random_uuid(),user_id uuid,track_id text,topics text[],question_ids uuid[],completed_at timestamptz,created_at timestamptz default now());`);
 await db.exec(read('content-releases/2026-09-27-final-revision-schema.sql'));
 await db.exec("alter table revision_items add column focus jsonb default '{}';alter table revision_sessions add column collection text default 'all';");
 for(const [u,role] of [[admin,'admin'],[teacher,'instructor'],[student,'student'],[outsider,'student'],[otherTeacher,'instructor'],[id(99),'student']]){
 await db.query('insert into auth.users(id,email) values($1,$2)',[u,u+'@example.test']);await db.query('insert into profiles(id,full_name,role,email) values($1,$2,$3,$4)',[u,role,role,u+'@example.test']);}
 await db.exec("insert into tracks(id,name) values('est','EST I'),('est2','EST II'),('est_eng','English') on conflict do nothing;");
 const qs={},groups={},exams={},oldAttempts={};let n=100;
 for(const track of tracks){
 await db.query('insert into instructor_tracks(user_id,track_id) values($1,$2),($3,$2)',[teacher,track,otherTeacher]);
 await db.query('insert into enrollments(user_id,track_id) values($1,$2),($3,$2)',[student,track,outsider]);
 await db.query('insert into portal_track_controls(track_id) values($1)',[track]);
 const g=id(n++);groups[track]=g;await db.query("insert into groups(id,track_id,name,instructor_id) values($1,$2,'Owned class',$3)",[g,track,teacher]);
 await db.query('insert into group_members values($1,$2)',[g,student]);
 qs[track]=[];for(let i=0;i<12;i++){
 const q=id(n++);qs[track].push(q);await db.query("insert into questions(id,track_id,topic,stem,choices,assets) values($1,$2,$3,'Synthetic complete question',$4::jsonb,'{\"verified_release\":\"test\",\"answer_review_status\":\"independently_solved\"}')",[q,track,i<6?'Algebra':'Geometry',JSON.stringify(['A','B','C','D'].map((key,j)=>({key,text:String(j+1)})))]);
 await db.query("insert into question_keys values($1,'\"A\"','Synthetic explanation')",[q]);}
 const ex=id(n++);exams[track]=ex;await db.query("insert into exams(id,track_id,title,duration_seconds,question_ids,is_published) values($1,$2,'Synthetic exam',600,$3::uuid[],true)",[ex,track,qs[track].slice(0,5)]);
 await db.query('insert into assignments(exam_id,group_id) values($1,$2)',[ex,g]);
 const a=id(n++);oldAttempts[track]=a;await db.query("insert into attempts(id,user_id,exam_id,attempt_no,shuffle_seed,deadline_at,status,score,total,started_at,submitted_at,review_unlocks_at) values($1,$2,$3,1,1,now()-interval '1 day','graded',1,5,now()-interval '2 days',now()-interval '2 days',now()-interval '1 day')",[a,student,ex]);
 await db.query('insert into attempt_results(attempt_id,question_id,is_correct) values($1,$2,false)',[a,qs[track][0]]);
 }
 const history=await scalar('select jsonb_agg(to_jsonb(a) order by id) from attempts a');
 await db.exec(read('content-releases/20261010_portal_management/functions-before.sql'));
 // Exact server definitions are retained, so rollout rejects later independent deployments.
 for(const part of ['01-core.sql','02-integrations.sql','03-integrations.sql'])await db.exec(read('content-releases/20261010_portal_management/'+part));

 await db.exec("create function public.default_group(p_track text) returns uuid language sql stable as $$select g.id from groups g join tracks t on t.id=g.track_id where g.track_id=p_track and g.name=t.name||' — all students' limit 1;$$;");
 for(const f of ['01-preference.sql','02-guards.sql','03-group-editor.sql'])await db.exec(read('content-releases/20261015_group_isolation/'+f));
 await db.exec(read('content-releases/20261015_group_isolation/daily-before.sql'));
 await db.exec(read('content-releases/20261015_group_isolation/04-daily.sql'));
 await db.exec(read('content-releases/20261015_group_isolation/05-default-plan-guard.sql'));
 await db.exec(read('content-releases/20261015_all_group_lessons/apply.sql'));
 // The synthetic setup from group_isolation_db.cjs is reused by the runner.
 const packet='content-releases/20261106_verified_daily/fixture-';
 await db.exec('create table public.daily_reset_archive(id uuid primary key default gen_random_uuid(),actor_id uuid,user_id uuid,track_id text,reset_mode text,previous_progress jsonb,created_at timestamptz default now());');
 const before=JSON.parse(read(packet+'before.json'));
 for(const f of before.daily)await db.exec(f.definition);
 await db.exec(before.portalManage);
 const zero='00000000-0000-0000-0000-000000000000';
 const date=await scalar("select (now() at time zone 'Africa/Cairo')::date::text");
 await db.query("insert into daily_progress(user_id,track_id,day,quiz_completed_at,quiz_score,points) values($1,'sat',$2::date-1,now(),5,60)",[student,date]);
 const oldDaily=await scalar('select jsonb_agg(to_jsonb(p) order by day) from daily_progress p');
 await db.exec(read('supabase/sql/daily_group_scores.sql'));
 ok(JSON.stringify(await scalar("select jsonb_agg(to_jsonb(p)-'group_scope' order by day) from daily_progress p"))===JSON.stringify(oldDaily),'Old daily rows preserved');
 await assert.rejects(()=>db.exec(read('supabase/sql/daily_group_scores.sql')),/daily_group_source_changed/);await db.exec('rollback');gates++;

 await db.exec("create schema if not exists portal_private; create table practice_notebook(user_id uuid,question_id uuid,correct_streak smallint default 0,tries int default 0,updated_at timestamptz default now(),primary key(user_id,question_id));");
 await db.exec(read('supabase/sql/verified_daily_checklist.sql'));
 const g=groups.sat, q=qs.sat[0], ex=exams.sat;
 const call=()=>scalar("select daily_group_state($1,'sat',$2)",[student,g]);
 let result=await call();
 ok(result.activity_status.focus==='pending'&&result.activity_status.review==='pending','New day pending');
 await assert.rejects(()=>scalar("select daily_group_mark($1,'sat','focus',$2)",[student,g]),/automatic_completion_required/);gates++;
 await assert.rejects(()=>scalar("select daily_mark($1,'sat','review')",[student]),/automatic_completion_required/);gates++;
 // A cached/manual flag is not evidence, but already earned scores are retained.
 await db.query("update daily_progress set focus_done=true,review_done=true,points=5,bonus_awarded=true where user_id=$1 and day=$2 and quiz_group_id=$3",[student,date,g]);
 result=await call();ok(!result.checklist.focus&&!result.checklist.review&&result.points_today===5,'Unverified current flags removed, points retained');
 await scalar("select daily_group_start($1,'sat',$2,$3::date)",[student,g,date]);
 result=await call();ok(result.activity_status.quiz==='started'&&!result.completed,'Started quiz is not completed');
 await scalar("select daily_group_start($1,'sat',$2,$3::date)",[student,g,date]);
 ok((await call()).points_today===5,'Repeated starts do not award points');
 await assert.rejects(()=>scalar("select daily_group_start($1,'sat',$2,$3::date-1)",[student,g,date]),/daily_date_changed/);gates++;
 // Viewing/seeding a notebook item is not practice. A wrong answer is started.
 await db.query('insert into practice_notebook(user_id,question_id) values($1,$2)',[student,q]);
 ok((await call()).activity_status.review==='pending','Viewing notebook stays pending');
 await db.query('update practice_notebook set tries=tries+1 where user_id=$1 and question_id=$2',[student,q]);
 ok((await call()).activity_status.review==='started','Wrong correction starts work');
 await db.query('update practice_notebook set tries=tries+1,correct_streak=1 where user_id=$1 and question_id=$2',[student,q]);
 ok((await call()).activity_status.review==='completed','Correct correction verified');
 await db.query('update practice_notebook set tries=tries+1,correct_streak=0 where user_id=$1 and question_id=$2',[student,q]);
 ok((await call()).activity_status.review==='completed','Later mistake cannot erase successful correction');
 const a=id(9901);
 await db.query("insert into attempts(id,user_id,exam_id,attempt_no,shuffle_seed,started_at,deadline_at,status) values($1,$2,$3,2,1,now(),now()+interval '1 hour','in_progress')",[a,student,ex]);
 ok((await call()).activity_status.focus==='started','Started lesson is not completed');
 await db.query('insert into attempt_answers(attempt_id,question_id,response) values($1,$2,$3::jsonb)',[a,q,'"B"']);
 ok((await call()).activity_status.focus==='started','Interrupted submission remains started');
 await db.query("update attempts set status='graded',submitted_at=now(),score=0,total=5 where id=$1",[a]);
 result=await call();ok(result.checklist.focus&&result.activity_status.focus_evidence.id===a,'Submitted lesson attempt counts, regardless of score');
 const shared=id(9902),other=id(9903);
 for(const [group,name] of [[shared,'Shared assignment'],[other,'Different assignment']]){
  await db.query("insert into groups(id,track_id,name,instructor_id) values($1,'sat',$2,$3)",[group,name,teacher]);
  await db.query('insert into group_members values($1,$2)',[group,student]);
 }
 await db.query('insert into assignments(exam_id,group_id) values($1,$2)',[ex,shared]);
 ok((await scalar("select daily_group_state($1,'sat',$2)",[student,shared])).checklist.focus,'Same exam can satisfy an explicitly shared group assignment');
 ok(!(await scalar("select daily_group_state($1,'sat',$2)",[student,other])).checklist.focus,'Unassigned exam cannot satisfy another group');
 ok(!(await scalar("select daily_group_state($1,'est',$2)",[student,groups.est])).checklist.review,'Course evidence isolated');
 // A complete drill is course practice; no group quiz scores are copied.
 const drill=id(9904);
 await db.query("insert into practice_drills(id,user_id,track_id,topics,question_ids) values($1,$2,'sat',array['Algebra'],$3)",[drill,student,qs.sat.slice(0,5)]);
 ok((await scalar("select daily_group_state($1,'sat',$2)",[student,other])).activity_status.focus==='started','Drill creation records started');
 await db.query('update practice_drills set completed_at=now() where id=$1',[drill]);
 const beforeQuiz=await scalar("select daily_group_state($1,'sat',$2)",[student,other]);
 ok(beforeQuiz.checklist.focus&&beforeQuiz.checklist.review&&!beforeQuiz.completed,'Course practice does not submit a group quiz');
 const answers=Object.fromEntries(beforeQuiz.quiz.map(q=>[q.id,'A']));
 const submit=()=>scalar("select daily_group_submit($1,'sat',$2::jsonb,$3,$4::date)",[student,JSON.stringify(answers),other,date]);
 result=await submit();ok(result.score===5&&result.points_today===65&&result.streak.current===1,'Existing grading and checklist bonus preserved');
 ok((await submit()).points_today===65,'Repeated submit is idempotent');
 // A failed transaction leaves neither a completed quiz nor partial points.
 await db.exec('begin');
 await db.query("update daily_progress set quiz_completed_at=null,points=0 where user_id=$1 and quiz_group_id=$2 and day=$3",[student,other,date]);
 await db.exec('rollback');ok((await call()).completed===false,'Other quiz remains independent');
 ok((await scalar("select daily_group_state($1,'sat',$2)",[student,other])).points_today===65,'Rollback retains committed result');
 const dayEvidence=await scalar("select portal_private.daily_checklist_evidence($1,'sat',$2,$3::date+1)",[student,g,date]);
 ok(dayEvidence.focus==='pending'&&dayEvidence.review==='pending','New Cairo day does not inherit practice');
 await login(student);await db.exec('set role authenticated');
 await assert.rejects(()=>db.query("select daily_group_start($1,'sat',$2,$3::date)",[outsider,g,date]),/permission denied/);gates++;
 await assert.rejects(()=>db.exec('select * from portal_private.notebook_activity'),/permission denied/);gates++;
 await assert.rejects(()=>db.query("update daily_progress set focus_done=true where user_id=$1",[outsider]),/permission denied/);gates++;
 await db.exec('reset role');
 ok(JSON.stringify(await scalar('select jsonb_agg(to_jsonb(a) order by id) from attempts a where id<>$1',[a]))===JSON.stringify(history),'Historical attempts unchanged');
 console.log('PASS: '+gates+' verified daily activity assertions');await db.close();
}
main().catch(async e=>{console.error(e.stack||e);await db.close();process.exitCode=1;});
