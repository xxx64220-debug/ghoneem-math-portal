// Actual assignment writer, delivery lookup and RLS, with disposable synthetic data only.
const {PGlite}=require('./june-review-runtime/node_modules/@electric-sql/pglite');
const fs=require('node:fs'),assert=require('node:assert/strict'),db=new PGlite();
const read=f=>fs.readFileSync(f,'utf8'),id=n=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
const admin=id(1),teacher=id(2),first=id(3),second=id(4),unselected=id(5),unenrolled=id(6);
const scalar=async(sql,args=[])=>Object.values((await db.query(sql,args)).rows[0])[0];
const save=(actor,exam,data)=>scalar('select portal_admin($1,\'assignment.save\',$2::jsonb)',[actor,JSON.stringify({exam_id:exam,...data})]);
async function main(){
 for(const f of ['tests/00_shim.sql','supabase/migrations/001_schema.sql','supabase/migrations/002_functions.sql','supabase/migrations/003_policies.sql','supabase/migrations/004_seed.sql','supabase/migrations/005_function_hardening.sql'])await db.exec(read(f).replace(/create extension if not exists pgcrypto;/g,''));
 // Load the checked-in writer itself; do not reimplement its authorization.
 await db.exec(read('supabase/sql/student_progress.sql').match(/create or replace function public\.portal_admin\([\s\S]*?end \$\$;/)[0]);
 await db.exec(read('supabase/migrations/20260924_prevent_duplicate_assignments.sql'));
 for(const [u,role] of [[admin,'admin'],[teacher,'instructor'],[first,'student'],[second,'student'],[unselected,'student'],[unenrolled,'student']]){
  await db.query('insert into auth.users(id,email) values($1,$2)',[u,u+'@example.test']);await db.query('insert into profiles(id,role,full_name) values($1,$2,$2)',[u,role]);
 }
 let n=100;
 for(const track of ['sat','est','est2','est_eng']){
  await db.query('insert into tracks(id,name) values($1,$1) on conflict do nothing',[track]);
  await db.query('insert into instructor_tracks(user_id,track_id) values($1,$2)',[teacher,track]);
  for(const u of [first,second,unselected])await db.query('insert into enrollments(user_id,track_id) values($1,$2)',[u,track]);
  const g=id(n++),exam=id(n++);await db.query('insert into groups(id,track_id,name,instructor_id) values($1,$2,$2,$3)',[g,track,teacher]);
  // All three students share a group, but it is deliberately not assigned.
  for(const u of [first,second,unselected])await db.query('insert into group_members values($1,$2)',[g,u]);
  await db.query("insert into exams(id,track_id,title,duration_seconds,question_ids,is_published) values($1,$2,'Synthetic assignment test',600,'{}',true)",[exam,track]);
  await save(admin,exam,{user_id:first});await save(teacher,exam,{user_id:second});
  assert(await scalar('select student_assignment_for($1,$2)',[exam,first]));assert(await scalar('select student_assignment_for($1,$2)',[exam,second]));
  assert.equal(await scalar('select student_assignment_for($1,$2)',[exam,unselected]),null,'unselected classmate cannot open exam');
  assert.equal((await scalar('select my_exams($1,$2)',[unselected,track])).length,0,'unselected classmate cannot list exam');
  await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:unselected})]);await db.exec('set role authenticated');
  assert.equal(await scalar('select count(*) from assignments where exam_id=$1',[exam]),0,'RLS hides direct assignments from classmates');await db.exec('reset role');
  await assert.rejects(()=>save(admin,exam,{user_id:unenrolled}),/student_not_enrolled/);
  await assert.rejects(()=>save(first,exam,{user_id:second}),/forbidden/);
  await assert.rejects(()=>save(admin,exam,{user_id:first,group_id:g}),/one_assignment_target_required/);
  await assert.rejects(()=>save(admin,exam,{user_id:first}),/duplicate key/);
  // Track membership alone does not authorize an instructor to assign a person.
  await db.query('delete from group_members where group_id=$1 and user_id=$2',[g,unselected]);
  await assert.rejects(()=>save(teacher,exam,{user_id:unselected}),/student_outside_your_groups/);
  await db.query("update assignments set open_at=now()+interval '1 day' where exam_id=$1 and user_id=$2",[exam,first]);
  assert.equal(await scalar('select student_assignment_for($1,$2)',[exam,first]),null,'opening time enforced');
  await db.query("update assignments set close_at=now()-interval '1 day' where exam_id=$1 and user_id=$2",[exam,second]);
  assert.equal(await scalar('select student_assignment_for($1,$2)',[exam,second]),null,'closing time enforced');
  await db.query('update assignments set open_at=null,close_at=null where exam_id=$1',[exam]);
  const g2=id(n++),foreign=id(n++),wrongTrack=id(n++);
  await db.query("insert into groups(id,track_id,name,instructor_id) values($1,$2,'Overlapping class',$3),($4,$2,'Other instructor',$5),($6,$7,'Other track',$3)",[g2,track,teacher,foreign,admin,wrongTrack,track==='sat'?'est':'sat']);
  await db.query('insert into group_members values($1,$2)',[g2,first]);
  await assert.rejects(()=>save(teacher,exam,{group_id:foreign}),/forbidden_group/);
  await assert.rejects(()=>save(admin,exam,{group_id:wrongTrack}),/forbidden_group/);
  await assert.rejects(()=>save(admin,exam,{group_id:g,open_at:'2026-11-02T10:00:00Z',close_at:'2026-11-01T10:00:00Z'}),/close_must_follow_open/);
  // Existing graded history survives adding two overlapping group targets.
  const historical=id(n++);
  await db.query("insert into attempts(id,user_id,exam_id,assignment_id,attempt_no,shuffle_seed,status,deadline_at,score,total) values($1,$2,$3,(select id from assignments where exam_id=$3 and user_id=$2),1,10,'graded',now(),7,10)",[historical,second,exam]);
  const history=await scalar('select to_jsonb(a)::text from attempts a where id=$1',[historical]);
  await save(teacher,exam,{group_id:g});await save(teacher,exam,{group_id:g2});
  assert.equal(await scalar('select to_jsonb(a)::text from attempts a where id=$1',[historical]),history);
  assert.equal((await scalar('select my_exams($1,$2)',[first,track])).filter(e=>e.id===exam).length,1,'overlap gives one exam card');
  assert.equal(await scalar('select count(*) from assignments where exam_id=$1',[exam]),4,'targets are independent, not expanded per member');
  const started=await scalar('select to_jsonb(start_attempt($1,$2))',[exam,first]);
  const resumed=await scalar('select to_jsonb(start_attempt($1,$2))',[exam,first]);
  assert.equal(started.id,resumed.id,'overlap resumes the same live attempt');
  assert.equal(await scalar('select count(*) from attempts where user_id=$1 and exam_id=$2',[first,exam]),1);
  await assert.rejects(()=>scalar('select start_attempt($1,$2)',[exam,second]),/attempt_limit_reached/,'overlap does not grant a retake');
  const groupAssignment=await scalar('select id from assignments where exam_id=$1 and group_id=$2',[exam,g]);
  await db.query("update assignments set close_at=now()-interval '1 day' where id=$1",[groupAssignment]);
  assert.notEqual(await scalar('select student_assignment_for($1,$2)',[exam,first]),groupAssignment,'expired overlap cannot mask open access');
  await db.query("update assignments set open_at=now()+interval '1 day' where exam_id=$1 and user_id=$2",[exam,first]);
  assert(await scalar('select student_assignment_for($1,$2)',[exam,first]),'future direct assignment cannot mask open group');
  await db.query("update assignments set close_at=now()-interval '1 day' where exam_id=$1 and group_id=$2",[exam,g2]);
  assert.equal(await scalar('select student_assignment_for($1,$2)',[exam,first]),null,'no active window denies new access');
  assert.equal(await scalar('select to_jsonb(a)::text from attempts a where id=$1',[historical]),history);
  await db.query('update exams set is_published=false where id=$1',[exam]);
  assert.equal(await scalar('select student_assignment_for($1,$2)',[exam,first]),null,'draft publication enforced');
 }
 assert.equal(await scalar('select count(*) from attempts'),8,'only explicit fixture history and starts create attempts');
 console.log('PASS: overlapping groups/direct recipients, unique cards/attempts, unchanged history, RLS, staff scope, duplicate guards and windows across SAT, EST I, EST II and English.');await db.close();
}
main().catch(async e=>{console.error(e.stack||e);await db.close();process.exitCode=1;});
