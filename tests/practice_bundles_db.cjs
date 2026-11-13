// Isolated PostgreSQL/WASM. No production URL or credentials.
const fs=require('node:fs'),assert=require('node:assert/strict'),{PGlite}=require(process.env.PGLITE_MODULE||'./device-runtime/node_modules/@electric-sql/pglite');
const db=new PGlite(),id=n=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0'),u=id(1),other=id(2),admin=id(3),tracks=['sat','est','est2','act2','est_eng','sat_eng'];let checks=0;
const eq=(a,b)=>{assert.deepEqual(a,b);checks++;},read=p=>fs.readFileSync(p,'utf8'),one=async(q,a=[])=>Object.values((await db.query(q,a)).rows[0])[0],reject=async(q,a,re)=>{await assert.rejects(()=>db.query(q,a),re);checks++;};
const call=(name,...args)=>{if(process.env.BUNDLE_HIERARCHY&&name==='create'&&args[1]==='sat'&&args[3]?.section==='Geometry')args[3]={...args[3],section:'Geometry and Trigonometry'};return one('select public.practice_bundle_'+name+'('+args.map((_,i)=>'$'+(i+1)).join(',')+')',args.map(x=>typeof x==='object'&&x!==null?JSON.stringify(x):x));};
(async()=>{
 await db.exec(`create schema portal_private;create schema extensions;
 create role anon;create role authenticated;create role service_role bypassrls;grant usage on schema public,portal_private to service_role;
 create table profiles(id uuid primary key,role text,status text default 'active',is_test boolean default false,full_name text);create table tracks(id text primary key,name text,is_active boolean default true);
 create table enrollments(user_id uuid,track_id text,status text default 'active',starts_at timestamptz,ends_at timestamptz);
 create table questions(id uuid primary key,track_id text,topic text,difficulty text,type text,stem text,choices jsonb,assets jsonb);
 create table question_keys(question_id uuid primary key,correct jsonb,explanation text);
 create table exams(id uuid primary key,track_id text,is_published boolean,question_ids uuid[]);
 create table attempts(id uuid primary key,user_id uuid,score integer);create table attempt_answers(attempt_id uuid,question_id uuid,response jsonb);
 create table question_catalogue(question_id uuid,reserve boolean);create table practice_notebook(user_id uuid,question_id uuid,tries integer);
 create table daily_progress(user_id uuid,answers jsonb);create table practice_drills(user_id uuid,answers jsonb);create table revision_sessions(user_id uuid,answers jsonb);
 grant select on all tables in schema public to service_role;`);
 await db.exec(read('tests/fixtures/bundle-live-dependencies.sql'));
 await db.exec(read('supabase/sql/question_eligibility_cache.sql'));
 await db.exec(read('supabase/sql/practice_bundles.sql'));
 if(process.env.BUNDLE_HIERARCHY)await db.exec(read('supabase/sql/practice_bundle_hierarchy.sql'));
 await db.query("insert into profiles(id,role,status,is_test,full_name) values($1,'student','active',true,'Test learner'),($2,'student','active',true,'Other test learner'),($3,'admin','active',false,'Admin')",[u,other,admin]);
 for(const [ti,t] of tracks.entries()){
  await db.query('insert into tracks(id,name) values($1,$1)',[t]);await db.query('insert into enrollments(user_id,track_id) values($1,$2)',[u,t]);
  for(let i=0;i<9;i++){const qid=id(100+ti*20+i),type=i===8?'grid_in':'mcq',assets={verified_release:'fixture',...(i===7?{release_hold_reason:'hold'}:{})};await db.query('insert into questions values($1,$2,$3,$4,$5,$6,$7,$8)',[qid,t,i<6?'Triangles and similarity':'Systems of equations',['easy','medium','hard'][i%3],type,'Synthetic fixture question '+i,JSON.stringify(type==='mcq'?['A','B','C','D'].map(key=>({key,text:key})):[]),JSON.stringify(assets)]);await db.query('insert into question_keys values($1,$2,$3)',[qid,JSON.stringify(type==='grid_in'?['1/2','0.5']:'A'),'Worked fixture solution']);}
  const cat=await call('catalog',u,t);eq(cat.topics.reduce((n,r)=>n+r.total,0),8);eq(cat.track,t);
 }
 const setting={section:'Geometry',topics:['Triangles and similarity'],difficulty:'easy',count:2,exclude_answered:true};
 await db.query("insert into profiles(id,role) values($1,'student')",[id(4)]);
 await db.query("insert into enrollments(user_id,track_id) values($1,'sat')",[id(4)]);
 await reject('select public.practice_bundle_catalog($1,$2)',[id(4),'sat'],/not_released/);
 await db.exec('update portal_private.practice_bundle_rollout set enabled=true');
 eq((await call('catalog',id(4),'sat')).test_account,false);
 await db.exec('update portal_private.practice_bundle_rollout set enabled=false');
 eq((await call('catalog',u,'sat')).test_account,true);
 await reject('select public.practice_bundle_catalog($1,$2)',[other,'sat'],/not_enrolled/);await reject('select public.practice_bundle_catalog($1,$2)',[admin,'sat'],/student_account/);
 const b=await call('create',u,'sat',id(900),setting,null);eq(b.questions.length,2);eq(b.questions.every(x=>x.topic==='Triangles and similarity'&&x.difficulty==='easy'),true);eq(b.questions.some(q=>q.correct||q.explanation),false);eq((await call('create',u,'sat',id(900),setting,null)).id,b.id);
 await reject('select public.practice_bundle_state($1,$2,$3)',[other,'sat',b.id],/not_enrolled/);
 await db.query("insert into enrollments(user_id,track_id) values($1,'sat')",[other]);await reject('select public.practice_bundle_state($1,$2,$3)',[other,'sat',b.id],/bundle_not_found/);
 await reject('select public.practice_bundle_save($1,$2,$3,0,$4,0,true)',[u,'sat',b.id,'{}'],/answer_all/);
 const answers={[b.question_ids[0]]:'A'};let saved=await call('save',u,'sat',b.id,0,answers,1,false);eq(saved.revision,1);
 eq((await call('save',u,'sat',b.id,0,answers,1,false)).revision,1); // lost-response retry
 await reject('select public.practice_bundle_save($1,$2,$3,0,$4,0,false)',[u,'sat',b.id,'{}'],/changed_elsewhere/);
 const resumed=await call('state',u,'sat',b.id);eq(resumed.answers,answers);eq(resumed.position,1);eq(resumed.completed_at,null);
 eq((await call('catalog',u,'sat')).topics.filter(x=>x.section===(process.env.BUNDLE_HIERARCHY?'Geometry and Trigonometry':'Geometry')).reduce((n,r)=>n+r.unseen,0),5);
 const shortage=await call('create',u,'sat',id(901),setting,null);eq(shortage.error,'not_enough_questions');eq(shortage.available,1);
 answers[b.question_ids[1]]='B';const complete=await call('save',u,'sat',b.id,1,answers,0,true);eq(complete.score,1);eq(complete.questions.every(q=>'correct'in q&&'explanation'in q),true);
 eq((await call('save',u,'sat',b.id,1,{},0,true)).score,1); // retry does not rewrite completed submission
 const retake=await call('create',u,'sat',id(902),{},b.id);eq(retake.question_ids,b.question_ids);eq(retake.answers,{});eq(retake.parent_id,b.id);eq(retake.questions.some(q=>q.correct),false);
 eq((await call('state',u,'sat',b.id)).answers,answers);
 await db.query("update questions set assets=assets||'{\"release_hold_reason\":\"new hold\"}'::jsonb where id=$1",[retake.question_ids[0]]);
 eq((await call('state',u,'sat',retake.id)).under_review,true);
 await reject('select public.practice_bundle_save($1,$2,$3,0,$4,0,false)',[u,'sat',retake.id,'{}'],/content_under_review/);eq((await call('state',u,'sat',b.id)).score,1);
 const grid=await call('create',u,'sat',id(903),{...setting,section:'',topics:['Systems of equations'],difficulty:'hard',count:1},null);
 await reject('select public.practice_bundle_save($1,$2,$3,0,$4,0,false)',[u,'sat',grid.id,JSON.stringify({[id(9999)]:'1'})],/invalid_answers/);
 eq((await call('save',u,'sat',grid.id,0,{[grid.question_ids[0]]:'0.50'},0,true)).score,1);
 // Reserve, changed content, cross-track, count bounds, malformed keys and permission attacks.
 await db.query('insert into question_catalogue values($1,true)',[id(101)]);eq((await call('catalog',u,'sat')).topics.reduce((n,r)=>n+r.total,0),6);
 await reject('select public.practice_bundle_create($1,$2,$3,$4,null)',[u,'sat',id(905),JSON.stringify({...setting,count:101})],/invalid_settings/);
 await reject('select public.practice_bundle_create($1,$2,$3,$4,null)',[u,'sat',id(906),JSON.stringify({...setting,topics:[42]})],/invalid_topics/);
 await reject('select public.practice_bundle_state($1,$2,$3)',[u,'est',b.id],/bundle_not_found/);
 const ch=await call('create',u,'est',id(907),{...setting,count:1},null);await db.query("update question_keys set correct='\"B\"' where question_id=$1",[ch.question_ids[0]]);eq((await call('state',u,'est',ch.id)).under_review,true);
 // History exclusion covers each old practice source; blanks never count.
 for(const [i,t] of ['daily_progress','practice_drills','revision_sessions'].entries())await db.query('insert into '+t+' values($1,$2)',[u,JSON.stringify({[id(120+i)]:'A'})]);
 await db.query('insert into practice_notebook values($1,$2,1)',[u,id(123)]);await db.query('insert into attempts values($1,$2,7)',[id(1000),u]);await db.query('insert into attempt_answers values($1,$2,\'"A"\'),($1,$3,\'""\')',[id(1000),id(124),id(125)]);
 eq((await one('select count(*)::int from portal_private.bundle_answered($1) where question_id=any($2)',[u,[120,121,122,123,124].map(id)])),5);
 eq((await one('select count(*)::int from portal_private.bundle_answered($1) where question_id=$2',[u,id(125)])),0);
 eq((await call('history',u,'sat',0)).items.length,3);eq(await one('select score from attempts where id=$1',[id(1000)]),7);
 for(const role of ['anon','authenticated']){await db.exec('set role '+role);await reject('select public.practice_bundle_catalog($1,$2)',[u,'sat'],/permission denied/);await reject('select * from public.practice_bundle_items',[],/permission denied/);await db.exec('reset role');}
 await db.exec('set role service_role');eq((await call('catalog',u,'sat')).track,'sat');await db.exec('reset role');
 eq(await one("select count(*)::int from pg_proc where proname like 'practice_bundle_%' and prosecdef"),0);
 // Missing or stale cache data falls back to live eligibility, never assumes readiness.
 const before=(await call('catalog',u,'sat')).topics.reduce((n,r)=>n+r.total,0);
 await db.query("update portal_private.question_eligibility_cache set rule_version='stale',exam_eligible=true where track_id='sat'");
 eq((await call('catalog',u,'sat')).topics.reduce((n,r)=>n+r.total,0),before);
 // New references must not obstruct existing account or question removal flows.
 const historical=await call('create',u,'act2',id(910),{...setting,count:1,exclude_answered:false},null);
 await call('save',u,'act2',historical.id,0,{[historical.question_ids[0]]:'A'},0,true);
 const openCopy=await call('create',u,'act2',id(911),{},historical.id);
 await db.query('delete from questions where id=$1',[historical.question_ids[0]]);
 eq((await call('state',u,'act2',historical.id)).score,1);
 eq((await call('state',u,'act2',historical.id)).questions.length,1);
 eq((await call('state',u,'act2',openCopy.id)).under_review,true);
 await reject('select public.practice_bundle_create($1,$2,$3,$4,$5)',[u,'act2',id(912),'{}',historical.id],/content_under_review/);
 const removedOwner=await call('create',other,'sat',id(913),{...setting,section:'',topics:[],difficulty:'mixed',count:1,exclude_answered:false},null);
 await db.query('delete from profiles where id=$1',[other]);
 eq(await one('select count(*)::int from practice_bundles where id=$1',[removedOwner.id]),0);
 eq(await one('select count(*)::int from practice_bundle_items where bundle_id=$1',[removedOwner.id]),0);
 await db.query("delete from portal_private.question_eligibility_cache where track_id='sat'");
 eq((await call('catalog',u,'sat')).topics.reduce((n,r)=>n+r.total,0),before);
 // A valid cache must avoid live eligibility work. Preserve the writer's search path
 // while stamping its function signature, including composite argument types.
 await db.exec(`create or replace function portal_private.question_eligible(p_q public.questions,p_k public.question_keys,p_track text,p_daily boolean default false)
 returns boolean language plpgsql as $$begin raise exception 'unexpected_live_eligibility';end$$;
 set search_path=public,pg_temp;
 update portal_private.question_eligibility_cache set rule_version=md5(pg_get_functiondef('portal_private.question_eligible(public.questions,public.question_keys,text,boolean)'::regprocedure)) where track_id='est2';
 reset search_path;`);
 eq((await call('catalog',u,'est2')).topics.reduce((n,r)=>n+r.total,0),8);
 await db.query("delete from portal_private.question_eligibility_cache where question_id=$1",[id(140)]);
 await reject('select public.practice_bundle_catalog($1,$2)',[u,'est2'],/unexpected_live_eligibility/);
 await db.close();console.log(checks+' practice bundle database assertions passed (six tracks, save/resume, retake, privacy, grading, holds and history).');
})().catch(e=>{console.error(e);process.exit(1)});
