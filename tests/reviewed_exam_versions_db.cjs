// Disposable PostgreSQL WASM. Never connects to Supabase or a network database.
const {PGlite}=require(process.env.PGLITE_MODULE||'@electric-sql/pglite');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'),read=f=>fs.readFileSync(path.join(root,f),'utf8');
const dir='content-releases/20261005_reviewed_exam_versions/';
const load=f=>JSON.parse(read(dir+f+'.json')),id=n=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
const before=load('before'),oldExams=load('exams'),changes=load('exam-changes'),adaptations=load('adaptations'),guards=load('guards');
const db=new PGlite();const scalar=async(sql,args=[])=>Object.values((await db.query(sql,args)).rows[0])[0];
const history=async()=>scalar("select jsonb_build_object('attempts',(select jsonb_agg(to_jsonb(a) order by id) from attempts a),'answers',(select jsonb_agg(to_jsonb(a) order by attempt_id,question_id) from attempt_answers a),'results',(select jsonb_agg(to_jsonb(a) order by attempt_id,question_id) from attempt_results a))");
async function main(){
 for(const f of ['tests/00_shim.sql','supabase/migrations/001_schema.sql'])await db.exec(read(f).replace(/create extension if not exists pgcrypto;/g,''));
 await db.exec(`alter table exams add column is_full_length boolean default false,add column assessment_type text default 'lesson_exam',add column scoring_map jsonb,add column exam_set_code text,add column module_number int,add column module_count int;
 create table revision_items(question_id uuid primary key,fingerprint text,active boolean);
 create table revision_sessions(id uuid primary key,snapshot jsonb);
 create table daily_quizzes(track_id text,day date,question_ids uuid[]);
 create table practice_drills(id uuid primary key,question_ids uuid[]);
 create table practice_notebook(user_id uuid,question_id uuid);
 insert into tracks(id,name) values('est','EST I'),('est2','EST II');
 insert into auth.users(id) values('${id(1)}');insert into profiles(id,role) values('${id(1)}','student');
 insert into enrollments(user_id,track_id) values('${id(1)}','est'),('${id(1)}','est2');
 create function is_enrolled(uuid,text) returns boolean language sql as $$select exists(select 1 from enrollments where user_id=$1 and track_id=$2 and status='active')$$;
 create function student_assignment_for(uuid,uuid) returns uuid language sql as $$select id from assignments where exam_id=$1 and (user_id=$2 or group_id in(select group_id from group_members where user_id=$2)) and (open_at is null or open_at<=now()) and (close_at is null or close_at>now()) order by id limit 1$$;`);
 const known=[...before,...load('canonical')];const extra=load('extra-interest-before');known.push({...extra.q,...extra.k});
 const pool=new Map();for(const e of oldExams)for(const q of e.question_ids)pool.set(q,e.track_id);
 for(const q of known)pool.set(q.id,q.track_id);
 for(const [qid,track] of pool){
  const q=known.find(q=>q.id===qid);
  if(q){
   await db.query('insert into questions(id,track_id,topic,difficulty,type,stem,choices,assets,created_at) values($1,$2,$3,$4,$5,$6,$7::jsonb,$8::jsonb,coalesce($9::timestamptz,now()))',[q.id,q.track_id,q.topic,q.difficulty||'medium',q.type||'mcq',q.stem,JSON.stringify(q.choices),JSON.stringify(q.assets),q.created_at||null]);
   await db.query('insert into question_keys values($1,$2::jsonb,$3)',[q.id,JSON.stringify(q.correct),q.explanation]);
  }else{
   // Healthy unchanged questions are synthetic; this suite claims no mathematical certification of them.
   await db.query("insert into questions(id,track_id,topic,stem,choices) values($1,$2,'Fixture','Unchanged fixture question','[{\"key\":\"A\",\"text\":\"1\"},{\"key\":\"B\",\"text\":\"2\"}]')",[qid,track]);
   await db.query("insert into question_keys values($1,'\"A\"','Synthetic unchanged solution')",[qid]);
  }
 }
 for(const e of oldExams)await db.query('insert into exams select (jsonb_populate_record(null::public.exams,$1::jsonb)).*',[JSON.stringify(e)]);
 const groups={est:id(10),est2:id(11)};
 for(const [track,g] of Object.entries(groups)){await db.query('insert into groups(id,track_id,name) values($1,$2,$2)',[g,track]);await db.query('insert into group_members values($1,$2)',[g,id(1)]);}
 for(const e of oldExams){
  await db.query('insert into assignments(exam_id,group_id,open_at,close_at) values($1,$2,$3,$4)',[e.id,groups[e.track_id],'2026-01-01','2027-01-01']);
  await db.query('insert into assignments(exam_id,user_id) values($1,$2)',[e.id,id(1)]);
 }
 let n=100;for(const c of changes.filter(c=>c.has_history)){
  const aid=id(n++);const live=c.old_id==='ce7d75b2-2195-43f8-b3a6-28f02951fcff';
  await db.query("insert into attempts(id,user_id,exam_id,assignment_id,attempt_no,shuffle_seed,deadline_at,status,score,total,review_unlocks_at) select $1,$2,$3,id,1,42,now()+interval '1 hour',$4,7,20,now() from assignments where exam_id=$3 order by id limit 1",[aid,id(1),c.old_id,live?'in_progress':'graded']);
  const q=oldExams.find(e=>e.id===c.old_id).question_ids[0];await db.query('insert into attempt_answers(attempt_id,question_id,response) values($1,$2,$3::jsonb)',[aid,q,'"A"']);await db.query('insert into attempt_results values($1,$2,true,1)',[aid,q]);
 }
 const eligibility=read('supabase/sql/question_eligibility.sql');
 await db.exec(eligibility.slice(eligibility.indexOf('-- A structural eligibility check'),eligibility.indexOf('CREATE OR REPLACE FUNCTION public.new_exam')));
 await db.exec(eligibility.slice(eligibility.indexOf('CREATE OR REPLACE FUNCTION public.attempt_payload'),eligibility.indexOf('CREATE OR REPLACE FUNCTION public.daily_state')));
 const originalQ=(await db.query('select q.*,k.correct,k.explanation from questions q join question_keys k on k.question_id=q.id order by q.id')).rows;
 const storedExams=(await db.query('select * from exams order by id')).rows;
 const originalAssignments=(await db.query('select * from assignments order by id')).rows,originalHistory=await history();
 let sql=read(dir+'apply.sql');const match=sql.match(/data_ jsonb:=('(?:[^']|'')*')::jsonb;/);assert.ok(match);
 const data=JSON.parse(match[1].slice(1,-1).replaceAll("''","'"));
 for(const g of data.guards.questions)g.hash=await scalar("select md5(jsonb_build_object('q',to_jsonb(q),'k',to_jsonb(k))::text) from questions q join question_keys k on k.question_id=q.id where q.id=$1",[g.id]);
 for(const g of data.guards.exams){g.hash=await scalar('select md5(to_jsonb(e)::text) from exams e where id=$1',[g.id]);g.assignment_hash=await scalar("select md5(coalesce(jsonb_agg(to_jsonb(a) order by a.id),'[]'::jsonb)::text) from assignments a where exam_id=$1",[g.id]);}
 data.extra.hash=await scalar("select md5(jsonb_build_object('q',to_jsonb(q),'k',to_jsonb(k))::text) from questions q join question_keys k on k.question_id=q.id where q.id=$1",[extra.q.id]);
 sql=sql.replace(match[1],"'"+JSON.stringify(data).replaceAll("'","''")+"'");
 assert.equal(await scalar('select count(*)::int from exams where not portal_private.exam_content_ready(question_ids,track_id)'),30);
 // A late exam mismatch must roll back the table creation, additions and any other writes.
 const last=changes.at(-1);const originalTitle=oldExams.find(e=>e.id===last.old_id).title;
 await db.query('update exams set title=title||$2 where id=$1',[last.old_id,' concurrent']);
 await assert.rejects(()=>db.exec(sql),/Concurrent exam change/);await db.exec('rollback');
 assert.equal(await scalar("select to_regclass('portal_private.exam_review_20261005_backup')"),null);
 assert.equal(await scalar('select count(*)::int from questions'),originalQ.length);assert.deepEqual(await history(),originalHistory);
 await db.query('update exams set title=$2 where id=$1',[last.old_id,originalTitle]);
 // Changes to a healthy member, assignments, or history reject the whole release as well.
 const healthy=originalQ.find(q=>!known.some(x=>x.id===q.id));await db.query('update questions set stem=stem||$2 where id=$1',[healthy.id,' concurrent']);
 await assert.rejects(()=>db.exec(sql),/Concurrent question change/);await db.exec('rollback');await db.query('update questions set stem=$2 where id=$1',[healthy.id,healthy.stem]);
 const aa=originalAssignments[0];await db.query("update assignments set close_at=now() where id=$1",[aa.id]);await assert.rejects(()=>db.exec(sql),/Concurrent assignment change/);await db.exec('rollback');await db.query('update assignments set close_at=$2 where id=$1',[aa.id,aa.close_at]);
 await db.exec(sql);assert.deepEqual(await history(),originalHistory);
 const post=(await db.query('select q.*,k.correct,k.explanation from questions q join question_keys k on k.question_id=q.id order by q.id')).rows;
 for(const q of originalQ){const now=post.find(x=>x.id===q.id);if(q.id===extra.q.id){assert.ok(now.assets.release_hold_reason);assert.deepEqual({...now,assets:q.assets},q);}else assert.deepEqual(now,q);}
 for(const c of changes){
  const e=(await db.query('select * from exams where id=$1',[c.new_id])).rows[0],old=oldExams.find(e=>e.id===c.old_id);
  assert.equal(await scalar('select portal_private.exam_content_ready(question_ids,track_id) from exams where id=$1',[e.id]),true);
  assert.deepEqual(e.question_ids,c.question_ids);assert.equal(e.question_ids.length,old.question_ids.length);
  for(const field of ['track_id','duration_seconds','shuffle','review_policy','scoring_map','exam_set_code','module_number','module_count'])assert.deepEqual(e[field],old[field]);
  assert.equal(e.assessment_type,c.assessment_type);assert.equal(e.max_attempts,c.max_attempts);
  if(c.has_history){const historyExam=(await db.query('select * from exams where id=$1',[c.old_id])).rows[0];assert.deepEqual({...historyExam,title:old.title},storedExams.find(e=>e.id===c.old_id));}
  const targets=await db.query('select group_id,user_id,open_at,close_at from assignments where exam_id=$1 order by group_id nulls first,user_id nulls first',[e.id]);
  assert.deepEqual(targets.rows,originalAssignments.filter(a=>a.exam_id===old.id).map(({group_id,user_id,open_at,close_at})=>({group_id,user_id,open_at,close_at})).sort((a,b)=>a.group_id===null?-1:b.group_id===null?1:0));
 }
 for(const a of originalAssignments)assert.deepEqual((await db.query('select * from assignments where id=$1',[a.id])).rows[0],a);
 const cards=[...await scalar('select my_exams($1,$2)',[id(1),'est']),...await scalar('select my_exams($1,$2)',[id(1),'est2'])];
 for(const c of changes)assert.ok(cards.find(e=>e.id===c.new_id).open);
 assert.equal(cards.filter(e=>e.content_ready===false).length,5);assert.ok(cards.filter(e=>!e.content_ready).every(e=>e.last&&e.title.includes('Historical version')));
 for(const a of originalHistory.attempts.filter(a=>a.status==='graded')){const payload=await scalar('select attempt_payload($1,$2)',[a.id,id(1)]);assert.equal(payload.questions.length,oldExams.find(e=>e.id===a.exam_id).question_ids.length);assert.ok(payload.questions.every(q=>!('correct'in q)));}
 assert.equal(await scalar("select has_table_privilege('authenticated','portal_private.exam_review_20261005_backup','select')"),false);
 assert.equal(await scalar("select has_table_privilege('anon','portal_private.exam_review_20261005_backup','select')"),false);
 await assert.rejects(()=>db.exec(sql),/already applied/);await db.exec('rollback');assert.deepEqual(await history(),originalHistory);
 // Rollback never discards a student's new exam or daily-practice history.
 await db.query('insert into daily_quizzes values($1,current_date,$2::uuid[])',['est',[adaptations[0].id]]);
 await assert.rejects(()=>db.exec(read(dir+'rollback.sql')),/practice history/);await db.exec('rollback');await db.query('delete from daily_quizzes');
 const replacement=changes.find(c=>c.has_history);await db.query("insert into attempts(id,user_id,exam_id,attempt_no,shuffle_seed,deadline_at,status) values($1,$2,$3,1,1,now(),'expired')",[id(999),id(1),replacement.new_id]);
 await assert.rejects(()=>db.exec(read(dir+'rollback.sql')),/Corrected version has attempts/);await db.exec('rollback');await db.query('delete from attempts where id=$1',[id(999)]);
 await db.exec(read(dir+'rollback.sql'));assert.deepEqual(await history(),originalHistory);
 assert.equal(await scalar('select count(*)::int from questions'),originalQ.length);
 for(const e of storedExams){const restored=(await db.query('select * from exams where id=$1',[e.id])).rows[0];assert.deepEqual(restored,{...e,is_published:changes.find(c=>c.old_id===e.id).has_history?e.is_published:false});}
 console.log('PASS: all 30 corrected assessments; 26 substitutions; 16 eligible adaptations; five historical versions, active/graded attempts, answers, marks and audiences preserved; unchanged source keys; exact counts/timers; correct full-exam settings; private backups; concurrent edits; replay rejection; safe rollback refusal after use.');
 await db.close();
}
main().catch(async e=>{console.error(e.message,e.where||'');await db.close();process.exitCode=1;});
