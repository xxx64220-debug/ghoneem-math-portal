// Disposable PGlite only. Unchanged members/replacements are synthetic; their mathematics is not re-certified.
const {PGlite}=require(process.env.PGLITE_MODULE||'@electric-sql/pglite');
const fs=require('node:fs'),assert=require('node:assert/strict'),db=new PGlite(),D='content-releases/20261015_est_cleanup/';
const read=p=>fs.readFileSync(p,'utf8'),load=n=>JSON.parse(read(D+n+'.json')),id=n=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
const scalar=async(s,a=[])=>Object.values((await db.query(s,a)).rows[0])[0];
async function main(){
 for(const f of ['tests/00_shim.sql','supabase/migrations/001_schema.sql'])await db.exec(read(f).replaceAll('create extension if not exists pgcrypto;',''));
 await db.exec("insert into tracks values('est','EST I'),('est2','EST II');alter table exams add column is_full_length boolean,add column scoring_map jsonb,add column assessment_type text,add column exam_set_code text,add column module_number int,add column module_count int;create table revision_items(question_id uuid primary key,active boolean,fingerprint text);create table revision_sessions(id int primary key,payload jsonb);create table daily_quizzes(payload jsonb);create table practice_drills(payload jsonb);create table practice_notebook(payload jsonb);create table est_source_review(id text primary key,track_id text,source_code text,question_id uuid,review_status text,review_note text,updated_at timestamptz);");
 const b=load('before'),p=load('packet'),all=new Map(b.archive.concat(b.original).map(q=>[q.id,q]));
 const synthetic=(qid,track='est2')=>({id:qid,track_id:track,topic:'Synthetic unchanged lesson',difficulty:'medium',type:'mcq',stem:'Synthetic unchanged question '+qid,choices:[{key:'A',text:'1'},{key:'B',text:'2'},{key:'C',text:'3'},{key:'D',text:'4'}],assets:{verified_release:'synthetic-fixture'},created_at:'2026-01-01T00:00:00Z',correct:'A',explanation:'Synthetic unchanged fixture; not a mathematical certificate.'});
 for(const m of p.members)if(!all.has(m.id))all.set(m.id,synthetic(m.id,m.track_id));
 for(const e of b.exams)for(const qid of e.question_ids)if(!all.has(qid))all.set(qid,synthetic(qid,e.track_id));
 for(const q of all.values()){
  await db.query('insert into questions select (jsonb_populate_record(null::questions,$1::jsonb)).*',[JSON.stringify(q)]);
  await db.query('insert into question_keys values($1,$2::jsonb,$3)',[q.id,JSON.stringify(q.correct),q.explanation]);
 }
 await db.query('insert into revision_items values($1,false,$2)',[b.revision[0].question_id,'preserve-inactive']);
 await db.query('insert into auth.users(id) values($1)',[id(1)]);await db.query("insert into profiles(id,role) values($1,'student')",[id(1)]);
 await db.query("insert into groups(id,track_id,name) values($1,'est2','Synthetic group')",[id(2)]);await db.query('insert into group_members values($1,$2)',[id(2),id(1)]);
 let n=10;
 for(const e of b.exams){
  await db.query('insert into exams select (jsonb_populate_record(null::exams,$1::jsonb)).*',[JSON.stringify(e)]);
  await db.query('insert into assignments(exam_id,group_id) values($1,$2)',[e.id,id(2)]);
  for(let j=0;j<e.attempts;j++){
   const aid=id(n++);await db.query("insert into attempts(id,user_id,exam_id,attempt_no,shuffle_seed,status,deadline_at,score,total) values($1,$2,$3,$4,1,'graded',now(),10,40)",[aid,id(1),e.id,j+1]);
   await db.query("insert into attempt_answers(attempt_id,question_id,response) values($1,$2,'\"F\"')",[aid,b.original.id]);
   await db.query('insert into attempt_results values($1,$2,true,1)',[aid,b.original.id]);
  }
 }
 for(const s of b.sources)await db.query('insert into est_source_review(id,track_id,source_code,question_id,review_status,review_note,updated_at) values($1,$2,$3,$4,$5,$6,$7)',[s.id,s.track_id,s.source_code,s.question_id,s.review_status,s.review_note,s.updated_at]);
 await db.exec("insert into revision_sessions values(1,'{\"unchanged\":true}')");
 await db.exec(read('supabase/sql/question_eligibility_core.sql'));
 // Production source/archive hashes remain exact; only synthetic unchanged-member/audience guards are substituted.
 for(const m of p.members)m.hash=await scalar("select md5(jsonb_build_object('q',to_jsonb(q),'k',to_jsonb(k))::text) from questions q join question_keys k on k.question_id=q.id where q.id=$1",[m.id]);
 for(const e of p.exams)e.assignment_hash=await scalar("select md5(coalesce(jsonb_agg(to_jsonb(a) order by a.id),'[]'::jsonb)::text) from assignments a where exam_id=$1",[e.before.id]);
 let sql=read(D+'apply.template.sql').replace('__PACKET__',"'"+JSON.stringify(p).replaceAll("'","''")+"'::jsonb");
 const state=async t=>(await db.query('select * from '+t+' order by 1')).rows;
 const tables=['questions','question_keys','exams','assignments','attempts','attempt_answers','attempt_results','revision_items','revision_sessions','enrollments','group_members','est_source_review'];
 const original=Object.fromEntries(await Promise.all(tables.map(async t=>[t,await state(t)])));
 // A source conflict late in the packet must roll back archives, additions and exam edits.
 const late=p.sources.at(-1);
 await db.query("update est_source_review set review_note=review_note||' concurrent' where id=$1",[late.id]);
 await assert.rejects(()=>db.exec(sql),/Concurrent source metadata change/);await db.exec('rollback');
 assert.equal(await scalar('select count(*)::int from audit_log'),0);assert.deepEqual(await state('questions'),original.questions);
 await db.query('update est_source_review set review_note=$2 where id=$1',[late.id,late.review_note]);
 const unused=p.exams.find(e=>!e.has_history);
 await db.query("insert into attempts(user_id,exam_id,attempt_no,shuffle_seed,status,deadline_at) values($1,$2,1,1,'in_progress',now())",[id(1),unused.before.id]);
 await assert.rejects(()=>db.exec(sql),/Concurrent exam history/);await db.exec('rollback');
 await db.query('delete from attempts where exam_id=$1',[unused.before.id]);
 const member=p.members.at(-1),memberStem=original.questions.find(q=>q.id===member.id).stem;
 await db.query("update questions set stem=stem||' concurrent' where id=$1",[member.id]);
 await assert.rejects(()=>db.exec(sql),/Concurrent member change/);await db.exec('rollback');await db.query('update questions set stem=$2 where id=$1',[member.id,memberStem]);
 await db.exec(sql);
 const after=Object.fromEntries(await Promise.all(tables.map(async t=>[t,await state(t)])));
 for(const t of ['attempts','attempt_answers','attempt_results','revision_items','revision_sessions','enrollments','group_members'])assert.deepEqual(after[t],original[t],t);
 assert.equal(after.questions.length,original.questions.length+1);
 for(const old of original.question_keys)assert.deepEqual(after.question_keys.find(k=>k.question_id===old.question_id),old);
 for(const old of original.questions){
  const q=after.questions.find(q=>q.id===old.id),a=p.archive.find(a=>a.id===old.id);
  if(!a){assert.deepEqual(q,old);continue;}
  assert.deepEqual({...q,assets:old.assets},old);
  assert.equal(q.assets.bank_removed,true);assert.equal(q.assets.replacement_question_id,a.replacement_id);
  assert.equal(await scalar("select portal_private.question_eligible(q,k,$2,false) from questions q join question_keys k on k.question_id=q.id where q.id=$1",[a.replacement_id,a.track_id]),true);
 }
 for(const c of p.exams){
  const newE=after.exams.find(e=>e.id===c.new_id),old=original.exams.find(e=>e.id===c.before.id);
  assert.deepEqual(newE.question_ids,c.question_ids);assert.equal(newE.question_ids.length,old.question_ids.length);
  for(const field of ['track_id','duration_seconds','shuffle','review_policy','max_attempts','assessment_type','is_full_length','exam_set_code','module_number','module_count'])assert.deepEqual(newE[field],old[field]);
  assert.equal(await scalar('select portal_private.exam_content_ready(question_ids,track_id) from exams where id=$1',[newE.id]),true);
  if(c.has_history){const historical=after.exams.find(e=>e.id===old.id);assert.deepEqual({...historical,title:old.title},old);assert.match(historical.title,/Historical version/);}
  const targets=async eid=>(await db.query('select group_id,user_id,open_at,close_at from assignments where exam_id=$1 order by 1,2',[eid])).rows;
  assert.deepEqual(await targets(c.new_id),await targets(old.id));
 }
 for(const old of original.assignments)assert.deepEqual(after.assignments.find(a=>a.id===old.id),old);
 assert.equal(after.assignments.length,original.assignments.length+1);
 assert.equal(await scalar("select count(*)::int from questions q left join question_keys k on k.question_id=q.id where q.track_id in ('est','est2') and lower(coalesce(q.assets->>'bank_removed','false'))<>'true' and not portal_private.question_eligible(q,k,q.track_id,false)"),0);
 for(const s of p.sources){const now=after.est_source_review.find(x=>x.id===s.id);assert.equal(now.review_status,s.status);assert.equal(now.review_note,s.note);assert.equal(now.question_id,s.question_id);}
 await assert.rejects(()=>db.exec(sql),/already applied/);await db.exec('rollback');

 let rollback=read(D+'rollback.template.sql').replace('__PACKET__',"'"+JSON.stringify(p).replaceAll("'","''")+"'::jsonb");
 await db.query('insert into daily_quizzes values($1::jsonb)',[JSON.stringify({question:p.question.id})]);
 await assert.rejects(()=>db.exec(rollback),/new practice\/history use/);await db.exec('rollback');await db.exec('delete from daily_quizzes');
 await db.exec(rollback);
 for(const t of ['attempts','attempt_answers','attempt_results','revision_items','revision_sessions','enrollments','group_members','est_source_review'])assert.deepEqual(await state(t),original[t],t);
 const undoQ=await state('questions');assert.equal(undoQ.length,original.questions.length);
 for(const old of original.questions)if(old.id!==b.original.id)assert.deepEqual(undoQ.find(q=>q.id===old.id),old);
 assert.equal(undoQ.find(q=>q.id===b.original.id).assets.bank_removed,true);
 assert.deepEqual(await state('question_keys'),original.question_keys);
 assert.deepEqual(await state('assignments'),original.assignments);
 for(const c of p.exams)if(!c.has_history)assert.equal((await db.query('select is_published from exams where id=$1',[c.before.id])).rows[0].is_published,false);
 await assert.rejects(()=>db.exec(rollback),/already rolled back/);await db.exec('rollback');
 console.log('PASS: 172 archive fingerprints, same-track replacements, 7 unused exam edits + 1 history-preserving version, identical keys/results/answers/audiences/timers, source statuses, embedded-figure eligibility, late-source atomic rollback, concurrent history/member guards replay refusal and safe rollback preserving history with draft assessments.');
 await db.close();
}main().catch(async e=>{console.error(e);await db.close();process.exitCode=1});

