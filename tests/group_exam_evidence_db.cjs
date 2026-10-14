// Isolated PostgreSQL WASM. No URL, credentials, network or production reads.
const {PGlite}=require(process.env.PGLITE_MODULE||'./june-review-runtime/node_modules/@electric-sql/pglite');
const fs=require('node:fs'),assert=require('node:assert/strict'),vm=require('node:vm');
const read=f=>fs.readFileSync(f,'utf8'),db=new PGlite();
const id=n=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
const staff=id(1),admin=id(2),other=id(3),students=Array.from({length:9},(_,i)=>id(10+i)),exam=id(50),group=id(60);
const scalar=async(sql,args=[])=>Object.values((await db.query(sql,args)).rows[0])[0];
const rpc=ids=>scalar('select staff_group_exam_evidence($1,$2::uuid[])',[exam,ids]);
const login=async user=>db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:user})]);
async function main(){
 for(const f of ['tests/00_shim.sql','supabase/migrations/001_schema.sql','supabase/migrations/002_functions.sql','supabase/migrations/003_policies.sql','supabase/migrations/004_seed.sql','supabase/migrations/005_function_hardening.sql'])await db.exec(read(f).replace(/create extension if not exists pgcrypto;/g,''));
 await db.exec("alter table exams add column is_full_length boolean default false, add column assessment_type text default 'lesson_exam';");
 for(const f of ['supabase/sql/portal_access.sql','supabase/sql/portal_scope.sql','supabase/sql/portal_upgrade.sql','supabase/sql/pending_exam_grading.sql','supabase/sql/group_exam_planning.sql'])await db.exec(read(f));
 for(const [u,role] of [[staff,'instructor'],[admin,'admin'],[other,'instructor'],...students.map(x=>[x,'student'])]){
  await db.query('insert into auth.users(id) values($1)',[u]);await db.query('insert into profiles(id,role) values($1,$2)',[u,role]);
 }
 await db.query("insert into instructor_tracks(user_id,track_id) values($1,'est'),($2,'est')",[staff,other]);
 await db.query("insert into groups(id,name,track_id,instructor_id) values($1,'Class','est',$2)",[group,staff]);
 for(const u of students){await db.query("insert into enrollments(user_id,track_id) values($1,'est')",[u]);}
 for(const u of students.slice(0,8))await db.query('insert into group_members(group_id,user_id) values($1,$2)',[group,u]);
 const questions=Array.from({length:12},(_,i)=>id(100+i));
 for(let i=0;i<questions.length;i++){
  await db.query("insert into questions(id,track_id,stem,topic,assets) values($1,'est','Synthetic question',$2,$3::jsonb)",[questions[i],i<6?'Fallback':'',JSON.stringify(i<5?{curriculum_lesson:'Circles'}:i>=6&&i<10?{curriculum_lesson:'Functions'}:{})]);
  await db.query('insert into question_keys(question_id,correct,explanation) values($1,$2::jsonb,$3)',[questions[i],i===4?' {"void":true}':'"A"','PRIVATE ANSWER EXPLANATION']);
 }
 await db.query("insert into exams(id,track_id,title,duration_seconds,question_ids,is_published,assessment_type) values($1,'est','Synthetic exact exam',2100,$2::uuid[],true,'lesson_exam')",[exam,[...questions,questions[0]]]);
 let counter=200;
 async function attempt(user,no,{score=3,locked=false,status='graded',date='2026-10-04T12:00:00Z',correct=false}={}){
  const a=id(counter++);
  // Insert responses while live, then complete without invoking grading.
  await db.query("insert into attempts(id,user_id,exam_id,attempt_no,shuffle_seed,deadline_at) values($1,$2,$3,$4,1,now()+interval '1 hour')",[a,user,exam,no]);
  for(let i=0;i<questions.length;i++)await db.query("insert into attempt_answers(attempt_id,question_id,response) values($1,$2,$3::jsonb)",[a,questions[i],i===0?'""':i===1?'null':'"B"']);
  await db.query("update attempts set status=$2,submitted_at=$3,score=$4,total=10,review_unlocks_at=$5 where id=$1",[a,status,date,score,locked?'2099-01-01T00:00:00Z':'2020-01-01T00:00:00Z']);
  if(score!==null)for(let i=0;i<questions.length;i++)if(i!==9)await db.query('insert into attempt_results(attempt_id,question_id,is_correct) values($1,$2,$3)',[a,questions[i],correct||i===2]);
  return a;
 }
 const old=await attempt(students[0],1,{correct:true,date:'2026-10-03T00:00:00Z'});
 const latest=await attempt(students[0],2);
 await attempt(students[1],1,{correct:true});await attempt(students[1],2,{locked:true,date:'2026-10-04T13:00:00Z'});
 await attempt(students[2],1,{score:null,status:'submitted'});
 // Student 3 has no completed attempt. Student 4 has a completed expired score.
 await attempt(students[4],1,{status:'expired'});
 await attempt(students[5],1,{correct:true});
 await attempt(students[6],1,{date:'2026-10-04T12:00:00Z',correct:true});const tie=await attempt(students[6],2,{date:'2026-10-04T12:00:00Z'});
 const empty=await attempt(students[7],1);await db.query('delete from attempt_results where attempt_id=$1',[empty]);
 await db.query('insert into assignments(exam_id,user_id) values($1,$2)',[exam,students[0]]);
 await db.query("insert into exams(id,track_id,title,duration_seconds,question_ids) values($1,'est','Synthetic exact exam',2100,$2::uuid[])",[id(51),questions]);
 await db.query("insert into exams(id,track_id,title,duration_seconds,assessment_type) values($1,'sat','Other track',2100,'full_exam')",[id(52)]);
 await db.query("insert into attempts(user_id,exam_id,attempt_no,shuffle_seed,deadline_at,status,score,total,submitted_at,review_unlocks_at) values($1,$2,1,1,now(),'graded',10,10,'2090-01-01','2020-01-01')",[students[0],id(51)]);
 const snapshot=()=>scalar("select jsonb_build_object('attempts',(select jsonb_agg(to_jsonb(a) order by id) from attempts a),'results',(select jsonb_agg(to_jsonb(r) order by attempt_id,question_id) from attempt_results r),'answers',(select jsonb_agg(to_jsonb(a) order by attempt_id,question_id) from attempt_answers a),'assignments',(select jsonb_agg(to_jsonb(a) order by id) from assignments a),'keys',(select jsonb_agg(to_jsonb(k) order by question_id) from question_keys k))");
 const before=await snapshot();await login(staff);await db.exec('set role authenticated');
 let evidence=await rpc(students.slice(0,8));assert.equal(evidence.students.length,8);
 const a=evidence.students.find(x=>x.user_id===students[0]);assert.equal(a.attempt.id,latest);assert.notEqual(a.attempt.id,old);
 assert.equal(evidence.students.find(x=>x.user_id===students[6]).attempt.id,tie);
 assert.equal(evidence.students.find(x=>x.user_id===students[1]).state,'locked');assert.deepEqual(evidence.students.find(x=>x.user_id===students[1]).lessons,[]);
 assert.equal(evidence.students.find(x=>x.user_id===students[2]).state,'ungraded');assert.equal(evidence.students.find(x=>x.user_id===students[3]).state,'missing');
 assert.equal(evidence.students.find(x=>x.user_id===students[4]).state,'available');assert.deepEqual(evidence.students.find(x=>x.user_id===students[7]).lessons,[]);
 const circles=a.lessons.find(x=>x.lesson==='Circles');assert.equal(circles.seen,4);assert.equal(circles.missed,3);assert.equal(circles.blank,2);
 assert.equal(a.lessons.find(x=>x.lesson==='Functions').seen,3);assert.equal(a.lessons.find(x=>x.lesson==='Fallback').seen,1);
 assert.equal(a.lessons.find(x=>x.lesson==='Unclassified questions').classified,false);
 // Compare the same released scored items with the actual student aggregator.
 await db.exec('reset role');const review=await scalar('select attempt_review($1,$2)',[latest,students[0]]);
 const source=read('web/portal-controls.js'),c={};vm.createContext(c);vm.runInContext(source.slice(source.indexOf('function finalsExamLessons'),source.indexOf('/* ===================== EST FINALS DIAGNOSIS')),c);
 const expected=c.finalsExamLessons(review.items.map(x=>({...x,topic:x.id===questions[5]?'Fallback':''}))).map(x=>[x.lesson,x.seen,x.correct,x.missed,x.blank,x.percent]);
 assert.deepEqual(JSON.parse(JSON.stringify(expected)),a.lessons.map(x=>[x.lesson,x.seen,x.correct,x.missed,x.blank,x.percent]));
 const encoded=JSON.stringify(evidence);assert(!/PRIVATE|question_id|response|explanation|stem|choices|awarded/.test(encoded),'aggregate must not return question details or keys');
 await db.exec('set role authenticated');
 await assert.rejects(()=>rpc([students[8]]),/student_scope_denied/);await assert.rejects(()=>rpc([students[0],id(999)]),/student_scope_denied/);
 await assert.rejects(()=>rpc([null]),/student_scope_denied/);await assert.rejects(()=>rpc(Array(101).fill(students[0])),/invalid_student_selection/);
 await assert.rejects(()=>scalar('select staff_group_exam_evidence($1,$2::uuid[])',[id(999),[students[0]]]),/exam_not_available/);
 await assert.rejects(()=>scalar('select staff_group_exam_evidence($1,$2::uuid[])',[id(52),[students[0]]]),/exam_not_available/);
 assert.equal((await rpc([students[0],students[0]])).students.length,1);
 await db.exec('reset role');
 for(const policy of ['score_only','instructor_release']){await db.query('update exams set review_policy=$2 where id=$1',[exam,policy]);await db.exec('set role authenticated');assert.equal((await rpc([students[0]])).students[0].state,'locked');await db.exec('reset role');}
 await db.query("update exams set review_policy='full_review' where id=$1",[exam]);
 await db.query("insert into groups(id,name,track_id,instructor_id) values($1,'Other track class','sat',$2)",[id(61),staff]);
 await db.query('insert into group_members(group_id,user_id) values($1,$2)',[id(61),students[8]]);
 await db.exec('set role authenticated');await assert.rejects(()=>rpc([students[8]]),/student_scope_denied/);
 await login(other);await assert.rejects(()=>rpc([students[0]]),/student_scope_denied/);
 await login(students[0]);await assert.rejects(()=>rpc([students[0]]),/staff_required/);
 await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:students[0],user_role:'admin',user_metadata:{role:'admin'}})]);await assert.rejects(()=>rpc([students[0]]),/staff_required/);
 await login(admin);assert.equal((await rpc(students)).students.length,9);
 await db.exec('reset role');await db.query('delete from instructor_tracks where user_id=$1',[staff]);await login(staff);await db.exec('set role authenticated');await assert.rejects(()=>rpc([students[0]]),/staff_required/);
 await db.exec('reset role');assert.equal(await scalar("select has_function_privilege('anon','public.staff_group_exam_evidence(uuid,uuid[])','EXECUTE')"),false);
 assert.deepEqual(await snapshot(),before,'staff reads must preserve all grades, attempts, answers, assignments and keys');
 console.log('PASS: isolated staff scopes, latest exact attempts, review locks, scored-only distinct aggregates, student-plan parity, no answer keys or writes');
 await db.close();
}
main().catch(async e=>{console.error(e);await db.close();process.exitCode=1;});
