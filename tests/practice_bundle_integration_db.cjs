// Isolated PostgreSQL only; never connects to the portal or production.
const fs=require('node:fs'),assert=require('node:assert/strict'),{PGlite}=require('./device-runtime/node_modules/@electric-sql/pglite');
const db=new PGlite(),read=f=>fs.readFileSync(f,'utf8'),id=n=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
const u=id(1),other=id(2),tracks=['sat','est','est2','act2','est_eng','sat_eng'];let serial=100,checks=0;
const eq=(a,b,m)=>{assert.deepEqual(a,b,m);checks++;},one=async(q,a=[])=>Object.values((await db.query(q,a)).rows[0])[0];
const call=(name,...args)=>one('select public.practice_bundle_'+name+'('+args.map((_,i)=>'$'+(i+1)).join(',')+')',args.map(x=>typeof x==='object'&&x!==null?JSON.stringify(x):x));
(async()=>{
 await db.exec(`create schema portal_private;create schema extensions;
 create role anon;create role authenticated;create role service_role bypassrls;grant usage on schema public,portal_private to service_role;
 create table profiles(id uuid primary key,role text,status text default 'active',is_test boolean default true,full_name text);create table tracks(id text primary key,name text,is_active boolean default true);
 create table enrollments(user_id uuid,track_id text,status text default 'active',starts_at timestamptz,ends_at timestamptz);
 create table questions(id uuid primary key,track_id text,topic text,difficulty text,type text,stem text,choices jsonb,assets jsonb);
 create table question_keys(question_id uuid primary key,correct jsonb,explanation text);
 create table exams(id uuid primary key,track_id text,is_published boolean,question_ids uuid[],review_policy text default 'full_review',title text default 'Fixture exam',assessment_type text default 'lesson_exam');
 create table attempts(id uuid primary key,user_id uuid,exam_id uuid,status text,score integer,total integer,scaled_score integer,time_used integer,submitted_at timestamptz,review_unlocks_at timestamptz,attempt_no int default 1,started_at timestamptz default now());
 create table attempt_answers(attempt_id uuid,question_id uuid,response jsonb);create table attempt_results(attempt_id uuid,question_id uuid,is_correct boolean);
 create table assignments(exam_id uuid,user_id uuid,group_id uuid);create table group_members(group_id uuid,user_id uuid);
 create table question_catalogue(question_id uuid,reserve boolean);
 create table practice_notebook(user_id uuid,question_id uuid,tries integer default 0,correct_streak smallint default 0,updated_at timestamptz default now(),primary key(user_id,question_id));
 create table daily_progress(user_id uuid,answers jsonb,track_id text,quiz_completed_at timestamptz);create table practice_drills(user_id uuid,answers jsonb);create table revision_sessions(user_id uuid,answers jsonb);
 create table portal_private.notebook_activity(user_id uuid,track_id text,day date,question_id uuid,started_at timestamptz,completed_at timestamptz,unique(user_id,track_id,day,question_id));
 create function public.exam_assigned_to(e uuid,u uuid) returns boolean language sql set search_path=public as $$select exists(select 1 from assignments where exam_id=e and user_id=u);$$;
 create function public.course_history_access(u uuid,t text) returns boolean language sql set search_path=public as $$select exists(select 1 from enrollments where user_id=u and track_id=t);$$;
 create function portal_private.diagnosis_daily(u uuid,t text,p_staff uuid default null) returns jsonb language sql as $$select '[]'::jsonb;$$;
 grant select on all tables in schema public to service_role;`);
 await db.exec(read('tests/fixtures/bundle-live-dependencies.sql'));
 await db.exec(read('supabase/sql/question_eligibility_cache.sql'));
 await db.exec(read('supabase/sql/practice_bundles.sql'));
 const before=JSON.parse(read('tests/fixtures/bundle-integration-before.json'));
 for(const x of before)await db.exec(x.definition.replace(" SET jit TO 'off'\n",'').replace(" SET plan_cache_mode TO 'force_custom_plan'\n",''));
 await db.exec('create trigger notebook_activity after update on practice_notebook for each row execute function portal_private.record_notebook_activity();');
 await db.query("insert into profiles(id,role) values($1,'student'),($2,'student')",[u,other]);
 const fixtures=[];
 for(const track of tracks){
  await db.query('insert into tracks(id,name) values($1,$1)',[track]);
  for(const user of [u,other])await db.query('insert into enrollments(user_id,track_id) values($1,$2)',[user,track]);
  const qs=[];
  for(let j=0;j<4;j++){
   const q=id(serial++);qs.push(q);
   await db.query("insert into questions values($1,$2,'Linear equations','medium',$3,'Fixture equation', $4,$5)",[q,track,j===3?'grid_in':'mcq',JSON.stringify(j===3?[]:['A','B','C','D'].map(key=>({key,text:key}))),JSON.stringify({verified_release:'fixture',curriculum_lesson:'Linear equations'})]);
   await db.query('insert into question_keys values($1,$2,$3)',[q,JSON.stringify(j===3?['1/2','0.5']:'A'),'Fixture explanation']);
  }
  const exam=id(serial++),a=id(serial++);
  await db.query('insert into exams(id,track_id,is_published,question_ids) values($1,$2,true,$3)',[exam,track,qs.slice(0,3)]);
  await db.query('insert into assignments(exam_id,user_id) values($1,$2)',[exam,u]);
  await db.query("insert into attempts(id,user_id,exam_id,status,score,total,submitted_at,review_unlocks_at) values($1,$2,$3,'graded',0,3,'2020-01-01','2020-01-01')",[a,u,exam]);
  for(const q of qs.slice(0,3)){await db.query("insert into attempt_answers values($1,$2,'\"B\"')",[a,q]);await db.query('insert into attempt_results values($1,$2,false)',[a,q]);}
  const bundle=await call('create',u,track,id(serial++),{count:4,topics:[],difficulty:'mixed',exclude_answered:false},null);
  const answers=Object.fromEntries(bundle.question_ids.map(q=>[q,q===qs[3]?'0.50':'B']));
  // A historical completed bundle exists before upgrading. One newer mastery must survive backfill.
  await call('save',u,track,bundle.id,0,answers,0,true);
  await db.query("update practice_bundles set completed_at='2021-01-01' where id=$1",[bundle.id]);
  await db.query("insert into practice_notebook values($1,$2,2,2,'2022-01-01')",[u,qs[0]]);
  fixtures.push({track,qs,exam,bundle,answers});
 }
 const snapshot=()=>one("select jsonb_build_object('attempts',(select jsonb_agg(a order by id) from attempts a),'answers',(select jsonb_agg(a order by attempt_id,question_id) from attempt_answers a),'results',(select jsonb_agg(r order by attempt_id,question_id) from attempt_results r),'assignments',(select jsonb_agg(a order by exam_id) from assignments a),'bundles',(select jsonb_agg(b order by id) from practice_bundles b),'daily',(select jsonb_agg(d) from daily_progress d))");
 const baseline=await snapshot(),scores=new Map();
 for(const {track} of fixtures)scores.set(track,await one('select student_dashboard($1,$2)',[u,track]));
 // PGlite preserves production function definitions and catches the real guards.
 await db.exec(read('supabase/sql/practice_bundle_hierarchy.sql'));
 await db.exec(read('supabase/sql/practice_bundle_integration.sql'));
 eq(await snapshot(),baseline,'migration preserves every assessment, bundle score, saved answer and assignment');
 for(const {track,qs,bundle,answers,exam} of fixtures){
  let lessons=await one('select portal_private.diagnosis_lessons($1,$2)',[u,track]);
  eq(lessons[0].seen,4,'bundle-only question enters evidence');eq(lessons[0].correct,1,'frozen grid-in equivalence');eq(lessons[0].bundle_seen,4);eq(lessons[0].exam_seen,0);eq(lessons[0].priority,'focus');
  eq(lessons,await one('select lessons from portal_private.diagnosis_lessons_batch($1,$2)',[[u],track]),'student/staff exact parity');
  const dash=await one('select student_dashboard($1,$2)',[u,track]);eq(dash.history,scores.get(track).history,'exam history intact');eq(dash.summary.completed,scores.get(track).summary.completed);eq(dash.summary.average_percent,scores.get(track).summary.average_percent);
  eq(await one('select correct_streak from practice_notebook where user_id=$1 and question_id=$2',[u,qs[0]]),2,'newer mastery survives history import');
  eq(await one('select count(*)::int from practice_notebook n join questions q on q.id=n.question_id where n.user_id=$1 and q.track_id=$2',[u,track]),3,'only wrong bundle answers enter notebook');
  const retake=await call('create',u,track,id(serial++),{},bundle.id);
  const right=Object.fromEntries(retake.question_ids.map(q=>[q,q===qs[3]?'1/2':'A']));
  await call('save',u,track,retake.id,0,right,0,false);
  eq(await one('select portal_private.diagnosis_lessons($1,$2)',[u,track]),lessons,'autosave is not diagnostic evidence');
  await call('save',u,track,retake.id,1,right,0,true);
  lessons=await one('select portal_private.diagnosis_lessons($1,$2)',[u,track]);eq(lessons[0].seen,4,'retakes never inflate distinct count');eq(lessons[0].correct,4);eq(lessons[0].priority,'strong');
  // The existing notebook API must expose imported errors without exposing answer keys.
  const notebook=await one('select practice_notebook_state($1,$2,0)',[u,track]);
  eq(notebook.remaining,2);eq(notebook.items.some(x=>'correct' in x||'explanation' in x),false);
  const activityBefore=await one('select count(*)::int from portal_private.notebook_activity');
  const fix1=await one('select practice_notebook_answer($1,$2,$3,$4)',[u,track,qs[1],'A']);
  const fix2=await one('select practice_notebook_answer($1,$2,$3,$4)',[u,track,qs[1],'A']);
  eq(fix1.correct,true);eq(fix2.mastered,true);eq(await one('select count(*)::int from portal_private.notebook_activity'),activityBefore+1,'only real notebook answers create Today evidence');
  const mistake=await call('create',u,track,id(serial++),{},bundle.id);
  await call('save',u,track,mistake.id,0,answers,0,true);
  eq(await one('select correct_streak from practice_notebook where user_id=$1 and question_id=$2',[u,qs[0]]),0,'new wrong submission reopens previously mastered mistake');
  eq(await one('select tries from practice_notebook where user_id=$1 and question_id=$2',[u,qs[0]]),2,'import does not impersonate notebook practice');
  await db.query('update practice_notebook set correct_streak=2 where user_id=$1 and question_id=$2',[u,qs[0]]);
  await call('save',u,track,mistake.id,0,{},0,true);
  eq(await one('select correct_streak from practice_notebook where user_id=$1 and question_id=$2',[u,qs[0]]),2,'lost-response retry cannot reset mastery');
  eq(await one('select portal_private.diagnosis_lessons($1,$2)',[other,track]),[],'another learner gets no evidence');
  await db.query("update questions set assets=assets||'{\"release_hold_reason\":\"hold\"}'::jsonb where id=$1",[qs[3]]);
  lessons=await one('select portal_private.diagnosis_lessons($1,$2)',[u,track]);eq(lessons[0].seen,3,'held question removed from live recommendations');
  eq((await call('state',u,track,retake.id)).score,4,'historical score remains frozen after hold');
  await db.query('update question_keys set explanation=$2 where question_id=$1',[qs[1],'Changed explanation']);
  lessons=await one('select portal_private.diagnosis_lessons($1,$2)',[u,track]);eq(lessons[0].bundle_seen,2,'changed fingerprint excludes stale bundle evidence');eq(lessons[0].exam_seen,1,'existing reviewed exam rules preserved');
  await db.query('insert into question_catalogue values($1,true)',[qs[2]]);
  lessons=await one('select portal_private.diagnosis_lessons($1,$2)',[u,track]);eq(lessons[0].bundle_seen,1,'reserved question not used as bundle evidence');
  // Latest locked/blank/pending exams still cannot displace released practice.
  const locked=id(serial++);await db.query("insert into attempts(id,user_id,exam_id,status,score,total,submitted_at,review_unlocks_at) values($1,$2,$3,'graded',3,3,now()+interval '1 minute',now()+interval '1 day')",[locked,u,exam]);
  await db.query("insert into attempt_answers values($1,$2,'\"A\"')",[locked,qs[0]]);await db.query('insert into attempt_results values($1,$2,true)',[locked,qs[0]]);
  eq(await one('select portal_private.diagnosis_lessons($1,$2)',[u,track]),lessons,'locked exam cannot displace released practice');
 }
 eq(await one('select count(*)::int from portal_private.notebook_activity'),6,'only the six real notebook corrections create Today evidence');
 eq(await one("select has_function_privilege('authenticated','portal_private.bundle_evidence(uuid[],text)','execute')"),false);eq(await one("select has_function_privilege('anon','portal_private.bundle_to_notebook()','execute')"),false);
 await assert.rejects(()=>db.exec(read('supabase/sql/practice_bundle_integration.sql')),/source_changed|already_installed/);await db.exec('rollback');checks++;
 console.log(`PASS: ${checks} connected-practice PostgreSQL checks across all six courses`);await db.close();
})().catch(async e=>{console.error(e);await db.close();process.exitCode=1;});
