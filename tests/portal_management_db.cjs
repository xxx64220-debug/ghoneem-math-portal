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
 for(const t of tracks){
 ok(await scalar('select is_enrolled($1,$2)',[student,t]),'Legacy access retained '+t);
 await db.query("update enrollments set starts_at=now()+interval '1 day' where user_id=$1 and track_id=$2",[student,t]);
 ok(!(await scalar('select is_enrolled($1,$2)',[student,t])),'Future access denied '+t);
 await assert.rejects(()=>db.query('select daily_state($1,$2)',[student,t]),/not_enrolled/);gates++;
 ok((await scalar('select student_dashboard($1,$2)',[student,t])).history.length===1,'Future access keeps history');
 await db.query("update enrollments set starts_at=now()-interval '3 days',ends_at=now()-interval '1 hour' where user_id=$1 and track_id=$2",[student,t]);
 ok(!(await scalar('select is_enrolled($1,$2)',[student,t])),'Expired access denied');
 ok(await scalar('select attempt_is_mine($1,$2)',[oldAttempts[t],student]),'History ownership retained');
 ok((await scalar('select attempt_review($1,$2)',[oldAttempts[t],student])).review_open,'Released review retained');
 ok(!(await scalar('select attempt_is_mine($1,$2)',[oldAttempts[t],outsider])),'Foreign history denied');
 await assert.rejects(()=>db.query('select daily_state($1,$2)',[student,t]),/not_enrolled/);gates++;
 await assert.rejects(()=>db.query('select portal_start_attempt($1,$2,false)',[exams[t],student]),/not_enrolled/);gates++;
 await db.query("update enrollments set status='paused' where user_id=$1 and track_id=$2",[student,t]);
 ok((await scalar('select student_dashboard($1,$2)',[student,t])).history.length===1,'Pause keeps history');
 await db.query("update enrollments set status='active',starts_at=null,ends_at=null where user_id=$1 and track_id=$2",[student,t]);
 for(const status of ['unrecorded','pending','paid','waived']){
 await db.query('update enrollments set payment_status=$3 where user_id=$1 and track_id=$2',[student,t,status]);ok(await scalar('select is_enrolled($1,$2)',[student,t]),'Permission separate from ledger');}
 }
 ok(await scalar('select jsonb_agg(to_jsonb(a) order by id) from attempts a').then(x=>JSON.stringify(x)===JSON.stringify(history)),'No history mutation');
 // Real RLS identity and admin authorization, stale claims cannot bypass active profile.
 await login(admin);await db.exec('set role authenticated');
 const en=await scalar("select admin_course_enrollments('sat')");ok(en.items.length===2,'Admin enrollment listing');
 const row=en.items.find(x=>x.user_id===student);
 const args=[student,'sat',JSON.stringify({status:'active',payment_status:'paid',course_label:'Next SAT',starts_at:null,ends_at:'2030-11-30T20:00:00Z'}),row.access_version];
 await db.query('select admin_save_course_access($1,$2,$3::jsonb,$4)',args);
 await assert.rejects(()=>db.query('select admin_save_course_access($1,$2,$3::jsonb,$4)',args),/access_changed_refresh/);gates++;
 const payArgs=[student,'sat',400,'EGP','2020-01-01','Receipt',id(900)];
 const p1=await scalar('select admin_record_course_payment($1,$2,$3,$4,$5,$6,$7)',payArgs);
 const p2=await scalar('select admin_record_course_payment($1,$2,$3,$4,$5,$6,$7)',payArgs);ok(p1.id===p2.id,'Idempotent receipt');
 await assert.rejects(()=>db.query('select admin_record_course_payment($1,$2,$3,$4,$5,$6,$7)',[...payArgs.slice(0,2),401,...payArgs.slice(3)]),/payment_request_conflict/);gates++;
 for(const bad of ['NaN','Infinity','-1','0','0.001']){await assert.rejects(()=>db.query('select admin_record_course_payment($1,$2,$3::numeric,$4,$5,$6,$7)',[student,'sat',bad,'EGP','2020-01-01','Invalid',id(901)]),/invalid_payment/);gates++;}
 await db.exec('reset role');ok(await scalar('select count(*)::int from course_payments')===1,'One immutable receipt');
 await db.query("update profiles set status='suspended' where id=$1",[student]);ok(!(await scalar('select course_history_access($1,\'sat\')',[student])),'Suspended history denied');
 await db.query("update profiles set status='active' where id=$1",[student]);
 await login(teacher);await db.exec('set role authenticated');
 for(const t of tracks){
 await db.query('select staff_save_group_plan($1,$2::jsonb,0)',[groups[t],JSON.stringify({target_exam_date:'2030-11-30',course_starts_on:null,course_ends_on:null,teaching_plan:'Diagnose, reteach and retest',daily_lessons:['Algebra']})]);gates++;
 const ops=await scalar('select staff_bank_operations($1,$2)',[t,groups[t]]);ok(ops.summary.students===1,'Only owned group student');ok(ops.items.find(x=>x.id===qs[t][0]).first_success===0,'First score exact');
 ok(!JSON.stringify(ops).includes('correct"')&&!JSON.stringify(ops).includes('Synthetic explanation'),'No keys');
 }
 await assert.rejects(()=>db.query('select admin_course_enrollments()'),/admin_required/);gates++;
 await db.exec('reset role');await login(otherTeacher);await db.exec('set role authenticated');
 await assert.rejects(()=>db.query('select staff_bank_operations(\'sat\',$1)',[groups.sat]),/group_scope_denied/);gates++;
 await db.exec('reset role');
 // Daily groups use exact lessons, freeze when first opened, and grade their own set.
 for(const t of tracks){
 const d=await scalar('select daily_state($1,$2)',[student,t]);ok(d.group_id===groups[t],'Owned group selected');ok(d.quiz.length===5&&d.quiz.every(q=>q.topic==='Algebra'),'Group lesson quiz');
 const answers=Object.fromEntries(d.quiz.map(q=>[q.id,'A']));await db.query('select daily_submit($1,$2,$3::jsonb)',[student,t,JSON.stringify(answers)]);
 ok((await scalar('select daily_state($1,$2)',[student,t])).score===5,'Group quiz graded');
 await db.query("update groups set daily_lessons=array['Geometry'] where id=$1",[groups[t]]);
 ok((await scalar('select daily_state($1,$2)',[student,t])).quiz.every(q=>q.topic==='Algebra'),'Frozen quiz retained after plan change');
 }
 // Timed continuation, bounded untimed grace and pause denial.
 const a=id(950);await db.query("insert into attempts(id,user_id,exam_id,attempt_no,shuffle_seed,started_at,deadline_at) values($1,$2,$3,2,1,now()-interval '30 minutes',now()+interval '30 minutes')",[a,student,exams.sat]);
 await db.query("update enrollments set ends_at=now()-interval '5 minutes' where user_id=$1 and track_id='sat'",[student]);
 ok(await scalar('select attempt_live_for($1,$2)',[a,student]),'Expiry allows timed continuation');
 await db.query("insert into attempt_answers values($1,$2,'\"A\"',now())",[a,qs.sat[0]]);gates++;
 ok((await scalar('select my_exams($1,\'sat\')',[student])).length===1,'Continuing exam remains visible');
 await db.query("update attempts set deadline_at='infinity' where id=$1",[a]);ok(await scalar('select attempt_live_for($1,$2)',[a,student]),'Bounded untimed continuation');
 await db.query("update enrollments set ends_at=now()-interval '3 hours' where user_id=$1 and track_id='sat'",[student]);ok(!(await scalar('select attempt_live_for($1,$2)',[a,student])),'Untimed grace ends');
 await db.query("update enrollments set status='paused',ends_at=null where user_id=$1 and track_id='sat'",[student]);ok(!(await scalar('select attempt_live_for($1,$2)',[a,student])),'Pause stops continuation');
 await db.query("update enrollments set status='active' where user_id=$1 and track_id='sat'",[student]);
 // Reserve catalogue never modifies content/fingerprints or historical exam eligibility.
 const assetsBefore=await scalar('select assets from questions where id=$1',[qs.sat[0]]);
 await login(admin);await db.exec('set role authenticated');
 let ops=await scalar("select staff_bank_operations('sat')");const q=ops.items.find(x=>x.id===qs.sat[0]);
 await db.query('select staff_question_reserve($1,true,$2,$3)',[q.id,'Reserve for future teaching',q.assets_hash]);
 ops=await scalar("select staff_bank_operations('sat',null,null,'reserve')");ok(ops.total===1,'Reserve filtering');
 await assert.rejects(()=>db.query('select staff_question_reserve($1,false,$2,$3)',[q.id,'Bring back to catalogue',q.assets_hash]),/question_changed_refresh/);gates++;
 await db.exec('reset role');ok(JSON.stringify(await scalar('select assets from questions where id=$1',[q.id]))===JSON.stringify(assetsBefore),'Reserve leaves content exact');
 ok(await scalar('select portal_private.exam_content_ready(question_ids,track_id) from exams where id=$1',[exams.sat]),'Existing exams stay eligible');
 // A repeat cannot inflate the unique-student denominator or contaminate a closed cycle.
 const repeat=id(970),closed=id(971),current=id(972);
 await db.query("insert into attempts(id,user_id,exam_id,attempt_no,shuffle_seed,deadline_at,status,score,total,started_at,submitted_at,review_unlocks_at) values($1,$2,$3,3,1,now()-interval '5 minutes','graded',5,5,now()-interval '15 minutes',now()-interval '5 minutes',now()-interval '5 minutes')",[repeat,student,exams.sat]);
 await db.query('insert into attempt_results(attempt_id,question_id,is_correct) values($1,$2,true)',[repeat,qs.sat[0]]);
 await db.query("insert into hardest_cycles(id,track_id,title,starts_at,ends_at) values($1,'sat','Previous trial','-infinity',now()-interval '1 day'),($2,'sat','New trial',now()-interval '1 day',null)",[closed,current]);
 await login(admin);await db.exec('set role authenticated');
 const allReport=await scalar("select staff_bank_operations('sat')");ok(allReport.summary.students===2,'Summary excludes students with no course or track history');
 const all=allReport.items.find(x=>x.id===qs.sat[0]);
 ok(all.unique_students===1&&all.responses>=2&&all.first_success===0&&all.latest_success===100&&all.repeat_improvement===100,'First/latest/improvement use one unique learner');
 const old=(await scalar("select staff_bank_operations('sat',null,$1)",[closed])).items.find(x=>x.id===qs.sat[0]);
 ok(old.responses===1&&old.first_success===0&&old.latest_success===0,'Previous trial excludes later repeat');
 const fresh=(await scalar("select staff_bank_operations('sat',null,$1)",[current])).items.find(x=>x.id===qs.sat[0]);
 ok(fresh.first_success===100&&fresh.latest_success===100,'New trial excludes prior responses');
 await assert.rejects(()=>db.query("select staff_bank_operations('est',null,$1)",[current]),/cycle_track_mismatch/);gates++;
 await db.exec('reset role');
 await db.query("update enrollments set status='paused' where user_id=$1 and track_id='sat'",[student]);
 await login(student);await db.exec('set role authenticated');
 const own=await db.query('select user_id from attempts');ok(own.rows.length>0&&own.rows.every(x=>x.user_id===student),'Paused history RLS retains only own rows');
 ok(await scalar('select count(*)::int from attempt_results')>0,'Paused own result rows retained');
 ok((await scalar('select my_course_access()')).length===4,'Student own course dates');
 ok(await scalar('select count(*)::int from course_payments')===0,'Student cannot see ledger');
 await assert.rejects(()=>db.query("select staff_bank_operations('sat')"),/staff_required/);gates++;
 await assert.rejects(()=>db.query('select admin_course_enrollments()'),/admin_required/);gates++;
 await db.exec('reset role');await db.query("select set_config('request.jwt.claims','{}',false)");await db.exec('set role anon');
 await assert.rejects(()=>db.query('select my_course_access()'),/permission denied/);gates++;
 await db.exec('reset role');
 ok(!(await scalar("select has_function_privilege('anon','public.staff_bank_operations(text,uuid,uuid,text,integer)','execute')")),'Anonymous denied');
 console.log(`PASS: ${gates} gates across all four tracks; legacy/future/expired/paused/renewed access, RLS ownership, history, payments, group quizzes, reserve and timed/untimed continuation.`);
 await db.close();
}
main().catch(async e=>{console.error(e.stack||e);await db.close();process.exitCode=1;});
