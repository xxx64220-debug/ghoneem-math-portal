// Disposable PostgreSQL WASM, synthetic accounts only; never contacts production.
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
 await login(admin);await db.exec('set role authenticated');
 const groupA=id(800),groupB=id(801),defaultId=id(802);
 const data={id:groupA,track_id:'sat',name:'Class A',instructor_id:teacher,members:[student,outsider],daily_lessons:['Algebra'],course_starts_on:null,course_ends_on:null,target_exam_date:'2026-11-07',teaching_plan:'A plan'};
 let a=await scalar('select staff_save_teaching_group($1::jsonb,null)',[JSON.stringify(data)]);ok(a.members.length===2,'Create explicit same-track membership');
 let b=await scalar('select staff_save_teaching_group($1::jsonb,null)',[JSON.stringify({...data,id:groupB,name:'Class B',members:[student],daily_lessons:['Geometry'],teaching_plan:'B plan'})]);
 const aHash=a.expected_hash;
 await assert.rejects(()=>scalar('select staff_save_teaching_group($1::jsonb,null)',[JSON.stringify({...data,id:id(899),name:' class a '})]),/group_name_already_used/);gates++;
 await assert.rejects(()=>scalar('select staff_save_teaching_group($1::jsonb,$2)',[JSON.stringify({...data,track_id:'est'}),aHash]),/group_track_is_fixed/);gates++;
 await assert.rejects(()=>scalar('select staff_save_teaching_group($1::jsonb,$2)',[JSON.stringify({...data,instructor_id:id(999)}),aHash]),/instructor_track_mismatch/);gates++;
 await db.exec('reset role');await db.query("update enrollments set status='paused',starts_at=now()+interval '1 day' where user_id=$1 and track_id='sat'",[outsider]);await db.exec('set role authenticated');
 a=await scalar('select staff_save_teaching_group($1::jsonb,$2)',[JSON.stringify({...data,name:'Renamed A'}),aHash]);ok(a.members.includes(outsider),'Paused/future member retained');
 await assert.rejects(()=>scalar('select staff_save_teaching_group($1::jsonb,$2)',[JSON.stringify(data),aHash]),/group_changed_refresh/);gates++;
 ok((await scalar('select staff_teaching_group_state($1)',[groupB])).expected_hash===b.expected_hash,'Other group unchanged');
 await db.exec('reset role');await db.query("insert into groups(id,track_id,name) select $1,'sat',name||' — all students' from tracks where id='sat'",[defaultId]);
 await db.query('insert into group_members values($1,$2)',[defaultId,student]);await db.exec('set role authenticated');
 const cohort=await scalar('select staff_teaching_group_state($1)',[defaultId]);await assert.rejects(()=>scalar('select staff_save_group_plan($1,$2::jsonb,0)',[defaultId,JSON.stringify({daily_lessons:[]})]),/default_cohort_protected/);gates++;await assert.rejects(()=>scalar('select staff_save_teaching_group($1::jsonb,$2)',[JSON.stringify({...data,id:defaultId,name:'Changed cohort'}),cohort.expected_hash]),/default_cohort_protected/);gates++;
 await db.exec('reset role');
 await db.query('update enrollments set daily_group_id=$1 where user_id=$2 and track_id=$3',[groupA,student,'sat']);
 await assert.rejects(()=>db.query('update enrollments set daily_group_id=$1 where user_id=$2 and track_id=$3',[groups.est,student,'sat']),/daily_group_membership_or_track_mismatch/);gates++;
 // Both groups supply distinct lessons; the explicit preference wins over creation order.
 let daily=await scalar("select daily_state($1,'sat')",[student]);ok(daily.group_id===groupA&&daily.quiz.every(q=>q.topic==='Algebra'),'Explicit primary group quiz');
 await db.query('update enrollments set daily_group_id=$1 where user_id=$2 and track_id=$3',[groupB,student,'sat']);
 ok((await scalar("select daily_state($1,'sat')",[student])).group_id===groupA,'Already-opened day stays frozen');
 // A different eligible student can exercise tomorrow-like fresh selection without changing history.
 await db.query("update enrollments set status='active',starts_at=null where user_id=$1 and track_id='sat'",[outsider]);
 await db.query('insert into group_members values($1,$2)',[groupB,outsider]);
 await db.query("update enrollments set daily_group_id=$1 where user_id=$2 and track_id='sat'",[groupB,outsider]);
 daily=await scalar("select daily_state($1,'sat')",[outsider]);ok(daily.group_id===groupB&&daily.quiz.every(q=>q.topic==='Geometry'),'Second group preserves its own quiz');
 // Group ranking uses evidence recorded for that group, never another group's points.
 await db.query("insert into daily_progress(user_id,track_id,day,points,quiz_group_id) values($1,'sat',(now() at time zone 'Africa/Cairo')::date-1,999,$2)",[student,groupA]);
 daily=await scalar("select daily_state($1,'sat')",[outsider]);ok(daily.leaderboard.every(x=>x.points!==999),'Cross-group points excluded');
 await db.query("update enrollments set daily_group_id=null where user_id=$1 and track_id='est'",[outsider]);
 await db.query("insert into groups(id,track_id,name,instructor_id) values($1,'est','Second class',$2)",[id(850),teacher]);await db.query('insert into group_members values($1,$2),($3,$2)',[id(850),outsider,groups.est]);
 ok((await scalar("select daily_state($1,'est')",[outsider])).group_id===null,'Ambiguous groups inherit track instead of newest group');
 await db.query('delete from group_members where group_id=$1 and user_id=$2',[groupB,student]);
 ok(await scalar("select daily_group_id is null from enrollments where user_id=$1 and track_id='sat'",[student]),'Removing membership clears only its preference');
 ok((await scalar("select daily_state($1,'sat')",[student])).group_id===groupA,'Removal does not rewrite opened daily progress');
 await login(otherTeacher);await db.exec('set role authenticated');await assert.rejects(()=>scalar('select staff_teaching_group_state($1)',[groupA]),/group_scope_denied/);gates++;
 await login(student);await assert.rejects(()=>scalar('select staff_teaching_group_state($1)',[groupA]),/staff_required/);gates++;
 await db.exec('set role anon');await assert.rejects(()=>scalar('select staff_teaching_group_state($1)',[groupA]),/permission denied/);gates++;
 await db.exec('reset role');ok(JSON.stringify(await scalar('select jsonb_agg(to_jsonb(a) order by id) from attempts a'))===JSON.stringify(history),'All exam history preserved');

 // Every selected lesson remains validated against the parent track, regardless of count.
 const manyLessons=['Algebra','Geometry'];
 for(let i=0;i<11;i++){const lesson='Extra lesson '+i;manyLessons.push(lesson);await db.query("insert into questions(id,track_id,topic,stem,choices) values($1,'sat',$2,'Synthetic lesson fixture','[]')",[id(900+i),lesson]);}
 await login(admin);await db.exec('set role authenticated');
 const all=await scalar('select staff_teaching_group_state($1)',[groupA]);
 const allData={...all.group,members:all.members,daily_lessons:manyLessons};
 const allSaved=await scalar('select staff_save_teaching_group($1::jsonb,$2)',[JSON.stringify(allData),all.expected_hash]);ok(allSaved.group.daily_lessons.length===13,'Group editor accepts thirteen real parent-track lessons');
 const planData={...allSaved.group,daily_lessons:manyLessons};const planSaved=await scalar('select staff_save_group_plan($1,$2::jsonb,$3)',[groupA,JSON.stringify(planData),allSaved.group.plan_version]);ok(planSaved.daily_lessons.length===13,'Course-plan endpoint accepts thirteen lessons');
 await assert.rejects(()=>scalar('select staff_save_group_plan($1,$2::jsonb,$3)',[groupA,JSON.stringify({...planData,daily_lessons:[...manyLessons,'Wrong track lesson']}),planSaved.plan_version]),/lesson_track_mismatch/);gates++;
 const stateAfter=await scalar('select staff_teaching_group_state($1)',[groupA]);await assert.rejects(()=>scalar('select staff_save_teaching_group($1::jsonb,$2)',[JSON.stringify({...allData,daily_lessons:[...manyLessons,'Wrong track lesson']}),stateAfter.expected_hash]),/lesson_track_mismatch/);gates++;
 await db.exec('reset role');ok((await scalar("select daily_state($1,'sat')",[student])).quiz.length===5,'Daily quiz still contains five questions');
 console.log(`PASS: ${gates} group-isolation gates: parent-track guards, protected cohorts, independent plans/members/quizzes, paused students, stale edits, preferences, frozen days and ranking isolation.`);await db.close();
}
main().catch(async e=>{console.error(e.stack||e);await db.close();process.exitCode=1;});
