// PostgreSQL WASM only: this test has no URL, network or production connection.
const {PGlite}=require(process.env.PGLITE_MODULE||'@electric-sql/pglite');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'),read=f=>fs.readFileSync(path.join(root,f),'utf8');
const dir='content-releases/20261004_question_reliability/';
const db=new PGlite(),id=n=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
const user=id(1),admin=id(2),literal=s=>"'"+s.replaceAll("'","''")+"'";
const scalar=async(sql,args=[])=>Object.values((await db.query(sql,args)).rows[0])[0];
const reject=async(sql,args,re)=>assert.rejects(()=>db.query(sql,args),re);
async function main(){
 for(const f of ['tests/00_shim.sql','supabase/migrations/001_schema.sql'])await db.exec(read(f).replace(/create extension if not exists pgcrypto;/g,''));
 await db.exec(`alter table exams add column is_full_length boolean default false,add column assessment_type text default 'lesson_exam',add column scoring_map jsonb,add column exam_set_code text,add column module_number int,add column module_count int;
 create table portal_track_controls(track_id text primary key,daily_mode text default 'random',daily_lessons text[] default '{}',daily_question_ids uuid[] default '{}',revision_visible boolean default true);
 create table revision_items(question_id uuid primary key references questions(id),lesson text,idea text,difficulty text,focus jsonb default '{}',programmes text[],fingerprint text,active boolean default true);
 create table revision_sessions(id uuid primary key default gen_random_uuid(),user_id uuid,access_track text,lesson text,collection text default 'all',snapshot jsonb,answers jsonb default '{}',created_at timestamptz default now(),completed_at timestamptz);
 create table panda_solution_pages(page integer primary key,figure text);
 create function public.default_group(p_track text) returns uuid language sql as $$select id from groups where track_id=p_track limit1$$;
 create function public.student_dashboard(p_user uuid,p_track text) returns jsonb language sql as $$select '{"lessons":[{"lesson":"Algebra","seen":10,"percent":30}]}'::jsonb$$;`.replace('limit1','limit 1'));
 for(const f of ['supabase/sql/daily_challenge.sql','supabase/migrations/20260924_exam_readiness_practice.sql'])await db.exec(read(f).split(/create or replace function/i)[0]);
 await db.exec(read('tests/fixtures/oct4-support-functions.sql'));
 await db.exec(read(dir+'functions-before.sql'));
 await db.exec(`insert into auth.users(id) values('${user}'),('${admin}');insert into profiles(id,role) values('${user}','student'),('${admin}','admin');
 insert into tracks(id,name) values('sat','SAT'),('est','EST I'),('est2','EST II'),('est_eng','English');
 insert into enrollments(user_id,track_id) select '${user}',id from tracks;
 insert into portal_track_controls(track_id) select id from tracks;
 insert into groups(track_id,name) select id,id from tracks;`);
 const choices=['A','B','C','D'].map((key,i)=>({key,text:String(i+1)})),perTrack={};let n=100;
 for(const track of ['sat','est','est2','est_eng']){
  perTrack[track]=[];
  for(let i=0;i<22;i++){
   const qid=id(n++);perTrack[track].push(qid);
   const assets={verified_release:'synthetic_fixture',...(i===21?{release_hold_reason:'Held synthetic item'}:{})};
   await db.query('insert into questions(id,track_id,topic,stem,choices,assets) values($1,$2,$3,$4,$5::jsonb,$6::jsonb)',[qid,track,'Algebra','Synthetic question',JSON.stringify(choices),JSON.stringify(assets)]);
   await db.query('insert into question_keys values($1,$2::jsonb,$3)',[qid,'"A"','Worked synthetic solution']);
  }
 }
 const badExam=id(900),goodExam=id(901),oldAttempt=id(902);
 await db.query("insert into exams(id,track_id,title,duration_seconds,question_ids,is_published) values($1,'est','Legacy exam',600,$2::uuid[],true),($3,'est','Safe exam',600,$4::uuid[],true)",[badExam,[perTrack.est[0],perTrack.est[21]],goodExam,perTrack.est.slice(0,5)]);
 await db.query('insert into assignments(exam_id,user_id) values($1,$3),($2,$3)',[badExam,goodExam,user]);
 await db.query("insert into attempts(id,user_id,exam_id,attempt_no,shuffle_seed,deadline_at,status,score,total,review_unlocks_at) values($1,$2,$3,1,1,now()+interval '1 hour','graded',1,2,now())",[oldAttempt,user,badExam]);
 await db.query('insert into attempt_results values($1,$2,false,0),($1,$3,false,0)',[oldAttempt,perTrack.est[0],perTrack.est[21]]);
 await db.query('insert into practice_notebook(user_id,question_id) values($1,$2),($1,$3)',[user,perTrack.est[0],perTrack.est[21]]);
 const historyBefore=(await db.query('select * from attempts')).rows;
 await db.exec(read('supabase/sql/question_eligibility.sql'));
 const check=(qid,track,daily=false)=>scalar('select portal_private.question_eligible(q,k,$2,$3) from questions q join question_keys k on k.question_id=q.id where q.id=$1',[qid,track,daily]);
 for(const t of Object.keys(perTrack)){assert.equal(await check(perTrack[t][0],t),true);assert.equal(await check(perTrack[t][0],t,true),true);assert.equal(await check(perTrack[t][21],t),false);}
 assert.equal(await check(perTrack.sat[0],'est'),false);
 const probe=perTrack.est[20];
 for(const [sql,value] of [['assets','{"bank_removed":true}'],['assets','{"figure_required":true}'],['choices','{}'],['choices','[{"key":"A","text":""},{"key":"B","text":"2"}]']]){
  await db.query('update questions set '+sql+'=$2::jsonb where id=$1',[probe,value]);assert.equal(await check(probe,'est'),false);
  await db.query('update questions set assets=$2::jsonb,choices=$3::jsonb where id=$1',[probe,'{"verified_release":"synthetic"}',JSON.stringify(choices)]);
 }
 await db.query('update question_keys set correct=$2::jsonb where question_id=$1',[probe,'["A","B"]']);assert.equal(await check(probe,'est'),true);assert.equal(await check(probe,'est',true),false);
 await db.query('update question_keys set correct=$2::jsonb where question_id=$1',[probe,'"Z"']);assert.equal(await check(probe,'est'),false);
 await db.query('update question_keys set correct=$2::jsonb where question_id=$1',[probe,'"A"']);
 await db.query("update questions set type='grid_in' where id=$1",[probe]);
 for(const key of ['[26,0.75,"3/4"]','26','"3/4"']){await db.query('update question_keys set correct=$2::jsonb where question_id=$1',[probe,key]);assert.equal(await check(probe,'est'),true);}
 await db.query("update questions set type='mcq' where id=$1",[probe]);await db.query('update question_keys set correct=$2::jsonb where question_id=$1',[probe,'"A"']);
 await db.query('update questions set choices=$2::jsonb,assets=$3::jsonb where id=$1',[probe,JSON.stringify(choices.map(c=>({...c,text:''}))),' {"figure":"data:image/svg+xml;base64,PHN2Zy8+","verified_release":"synthetic"}']);
 assert.equal(await check(probe,'est'),true);assert.equal(await check(probe,'est',true),false);
 await db.query('update questions set assets=$2::jsonb,choices=$3::jsonb where id=$1',[probe,'{"verified_release":"synthetic"}',JSON.stringify(choices)]);
 await reject('select portal_admin($1,$2,$3::jsonb)',[admin,'exam.save',JSON.stringify({id:badExam,is_published:true})],/exam_content_under_review/);
 await reject('select portal_start_attempt($1,$2,false)',[badExam,user],/exam_content_under_review/);
 const exams=await scalar('select my_exams($1,$2)',[user,'est']);assert.equal(exams.find(e=>e.id===badExam).content_ready,false);assert.equal(exams.find(e=>e.id===badExam).open,false);assert.equal(exams.find(e=>e.id===badExam).last.id,oldAttempt);
 const started=await scalar('select to_jsonb(portal_start_attempt($1,$2,true))',[goodExam,user]);assert.equal(started.status,'in_progress');
 await db.query('update questions set assets=assets||$2::jsonb where id=$1',[perTrack.est[1],'{"release_hold_reason":"held after start"}']);
 await reject('select attempt_payload($1,$2)',[started.id,user],/exam_content_under_review/);
 await reject('select portal_start_attempt($1,$2,true)',[goodExam,user],/exam_content_under_review/);
 await db.query("update questions set assets=assets-'release_hold_reason' where id=$1",[perTrack.est[1]]);
 const notebook=await scalar('select practice_notebook_state($1,$2,0)',[user,'est']);assert.equal(notebook.remaining,1);assert.deepEqual(notebook.items.map(x=>x.id),[perTrack.est[0]]);
 await reject('select practice_notebook_answer($1,$2,$3,$4)',[user,'est',perTrack.est[21],'A'],/question_content_under_review/);
 for(const t of Object.keys(perTrack)){
  const malformed=perTrack[t][20];await db.query('update questions set choices=$2::jsonb where id=$1',[malformed,'{}']);
  const daily=await scalar('select daily_state($1,$2)',[user,t]);assert.equal(daily.quiz.length,5);assert.ok(daily.quiz.every(q=>!q.assets.release_hold_reason));
  assert.ok(daily.quiz.every(q=>q.id!==malformed));await db.query('update questions set choices=$2::jsonb where id=$1',[malformed,JSON.stringify(choices)]);
  const drill=await scalar('select practice_drill_start($1,$2)',[user,t]);assert.equal(drill.questions.length,18);assert.ok(drill.questions.every(q=>!q.assets.release_hold_reason));
  const selected=daily.quiz[0].id;await db.query('update questions set assets=assets||$2::jsonb where id=$1',[selected,'{"release_hold_reason":"cached quiz held"}']);
  await reject('select daily_state($1,$2)',[user,t],/daily_content_under_review/);
  await db.query("update questions set assets=assets-'release_hold_reason' where id=$1",[selected]);
  const responses=Object.fromEntries(daily.quiz.map(q=>[q.id,'A']));
  const completed=await scalar('select daily_submit($1,$2,$3::jsonb)',[user,t,JSON.stringify(responses)]);assert.equal(completed.score,5);
  await db.query('update questions set assets=assets||$2::jsonb where id=$1',[selected,'{"release_hold_reason":"completed quiz held"}']);
  assert.equal((await scalar('select daily_state($1,$2)',[user,t])).completed,true);
  await db.query("update questions set assets=assets-'release_hold_reason' where id=$1",[selected]);
 }
 await reject("select new_exam('est','Ambiguous lesson',5,10,'Alge',true,false)",[],/no_questions_matched/);
 const created=await scalar("select new_exam('est','Exact lesson',10,10,'Algebra',true,false)");assert.equal(await scalar('select portal_private.exam_content_ready(question_ids,track_id) from exams where id=$1',[created]),true);
 for(const qid of perTrack.est.slice(0,12))await db.query("insert into revision_items(question_id,lesson,idea,difficulty,programmes,fingerprint) select q.id,q.topic,q.id::text,q.difficulty,array['est'],revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation) from questions q join question_keys k on k.question_id=q.id where q.id=$1",[qid]);
 const catalogue=await scalar("select final_revision($1,'est','catalogue')",[user]);assert.equal(catalogue.items.length,12);assert.ok(catalogue.items.every(q=>!('assets'in q)&&!('stem'in q)&&!('correct'in q)));
 const rev=await scalar("select final_revision($1,'est','start','{\"count\":\"10\"}')",[user]);assert.equal(rev.questions.length,10);assert.ok(rev.questions.every(q=>q.stem&&q.assets&&!('correct'in q)));
 assert.deepEqual((await db.query('select * from attempts where id=$1',[oldAttempt])).rows,historyBefore);
 assert.equal(await scalar("select has_function_privilege('authenticated','portal_private.question_eligible(questions,question_keys,text,boolean)','execute')"),false);
 await assert.rejects(()=>db.exec(read('supabase/sql/question_eligibility.sql')),/Function changed since reviewed/);await db.exec('rollback');
 const originals=JSON.parse(read('tests/fixtures/oct4-questions-before.json')),patches=JSON.parse(read(dir+'repairs.json'));
 assert.equal(patches.length,12);
 const recovered=originals.filter(q=>q.assets.verified_release==='20261004-source-recovery');
 assert.equal(recovered.length,3);assert.ok(recovered.every(q=>!patches.some(p=>p.id===q.id)));
 for(const q of originals){
  await db.query('insert into questions(id,track_id,topic,type,stem,choices,assets) values($1,$2,$3,$4,$5,$6::jsonb,$7::jsonb)',[q.id,q.track_id,q.topic,q.type,q.stem,JSON.stringify(q.choices),JSON.stringify(q.assets)]);
  await db.query('insert into question_keys values($1,$2::jsonb,$3)',[q.id,JSON.stringify(q.correct),q.explanation]);
  if(q.revision_fingerprint)await db.query("insert into revision_items(question_id,lesson,idea,difficulty,programmes,fingerprint,active) values($1,'Original lesson','Original idea','medium',array['sat'],$2,$3)",[q.id,q.revision_fingerprint,q.revision_active]);
 }
 const snap=async()=>(await db.query('select q.*,k.correct,k.explanation from questions q join question_keys k on k.question_id=q.id order by q.id')).rows;
 const before=await snap(),examBefore=(await db.query('select * from exams order by id')).rows,attemptsBefore=(await db.query('select * from attempts order by id')).rows;
 const last=originals.find(q=>q.id===patches.at(-1).id);await db.query('update question_keys set explanation=$2 where question_id=$1',[last.id,last.explanation+' concurrent edit']);
 await assert.rejects(()=>db.exec(read(dir+'apply.sql')),/Concurrent content change/);await db.exec('rollback');
 assert.equal(await scalar("select to_regclass('public.question_reliability_20261004_backup')"),null);
 await db.query('update question_keys set explanation=$2 where question_id=$1',[last.id,last.explanation]);assert.deepEqual(await snap(),before);
 await db.exec(read(dir+'apply.sql'));const after=await snap();
 for(const old of before){const patch=patches.find(p=>p.id===old.id),now=after.find(q=>q.id===old.id);assert.deepEqual(now,patch?{...old,choices:patch.choices||old.choices,assets:{...old.assets,...patch.asset_patch},explanation:patch.explanation||old.explanation}:old,old.id);}
 assert.deepEqual((await db.query('select * from exams order by id')).rows,examBefore);assert.deepEqual((await db.query('select * from attempts order by id')).rows,attemptsBefore);
 assert.equal(await scalar('select count(*)::int from question_reliability_20261004_backup'),12);
 for(const q of recovered)assert.equal(await check(q.id,q.track_id),true,'Recovered source item remains eligible: '+q.id);
 assert.equal(await scalar("select count(*)::int from revision_items r join questions q on q.id=r.question_id join question_keys k on k.question_id=q.id where r.active and r.fingerprint<>revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation)"),0);
 await assert.rejects(()=>db.exec(read(dir+'apply.sql')),/Concurrent content change|duplicate key/);await db.exec('rollback');assert.deepEqual(await snap(),after);
 await db.exec(read(dir+'rollback.sql'));assert.deepEqual(await snap(),before);assert.equal(await scalar('select count(*)::int from question_reliability_20261004_backup'),0);
 await db.exec(read(dir+'apply.sql'));assert.deepEqual(await snap(),after);
 console.log('PASS: every active track; malformed/held/removed/visual/numeric key cases; publish-only rejection; start/resume guard; historical scores; notebook; frozen daily sets; drills; exact lesson selection; keyless metadata and hydrated revision; private helper privileges; migration replay guard; 12 guarded content repairs, three recovered source records preserved and eligible, late-error rollback, fingerprints, retained keys/IDs/track/assets/membership/results, and release replay rejection.');
 await db.close();
}
main().catch(async e=>{console.error(e.message,e.position||'',e.where||'',e.query?.slice(Math.max(0,Number(e.position)-80),Number(e.position)+80)||'');await db.close();process.exitCode=1;});
