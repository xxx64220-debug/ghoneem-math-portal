// Isolated PostgreSQL/WASM. No production URL or credentials.
const fs=require('node:fs'),assert=require('node:assert/strict'),{PGlite}=require(process.env.PGLITE_MODULE||'./device-runtime/node_modules/@electric-sql/pglite');
const db=new PGlite(),id=n=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0'),u=id(1),other=id(2),admin=id(3),tracks=['sat','est','est2','act2','est_eng','sat_eng'];let checks=0;
const eq=(a,b)=>{assert.deepEqual(a,b);checks++;},read=p=>fs.readFileSync(p,'utf8'),one=async(q,a=[])=>Object.values((await db.query(q,a)).rows[0])[0],reject=async(q,a,re)=>{await assert.rejects(()=>db.query(q,a),re);checks++;};
const call=(name,...args)=>one('select public.practice_bundle_'+name+'('+args.map((_,i)=>'$'+(i+1)).join(',')+')',args.map(x=>typeof x==='object'&&x!==null?JSON.stringify(x):x));
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
 for(const [ti,t] of tracks.entries())await db.query("insert into questions(id,track_id,topic,assets) values($1,$2,'Existing lesson',$3)",[id(80000+ti),t,JSON.stringify({lesson_subtopic:'Existing subtopic'})]);
 await db.exec(read('supabase/sql/practice_bundle_hierarchy.sql'));
 eq(await one("select count(*)::int from portal_private.bundle_subtopics where subtopic='Existing subtopic'"),6);
 await db.query('delete from questions where id=any($1)',[tracks.map((_,i)=>id(80000+i))]);
 eq(await one('select count(*)::int from portal_private.bundle_subtopics'),0);
 await db.query("insert into profiles(id,role,is_test) values($1,'student',true),($2,'student',true)",[u,other]);
 for(const t of tracks){await db.query('insert into tracks(id,name) values($1,$1)',[t]);await db.query('insert into enrollments(user_id,track_id) values($1,$2),($3,$2)',[u,t,other]);}
 const choices=JSON.stringify([{key:'A',text:'2'},{key:'B',text:'3'}]);
 const topics=['Linear functions and slope','Quadratics and polynomials','Statistics and data analysis','Triangles and similarity'];
 for(let i=0;i<120;i++){
  const topic=topics[Math.floor(i/30)],sub=i%3===0?'':i%3===1?'First skill':'Second skill',qid=id(100+i);
  await db.query(`insert into questions values($1,'sat',$2,$3,'mcq','Synthetic $x^2$ question',$4,$5)`,[qid,topic,['easy','medium','hard'][i%3],choices,JSON.stringify({verified_release:'fixture',lesson_subtopic:sub})]);
  await db.query(`insert into question_keys values($1,'"A"','PRIVATE explanation')`,[qid]);
 }
 const setting={section:'',topics:[],subtopics:[],difficulty:'mixed',count:10,exclude_answered:true};
 let catalog=await call('catalog',u,'sat');
 eq(catalog.subtopics_supported,true);eq(catalog.topics.reduce((n,r)=>n+r.total,0),120);
 eq([...new Set(catalog.topics.map(r=>r.section))].sort(),['Advanced Math','Algebra','Geometry and Trigonometry','Problem-Solving and Data Analysis'].sort());
 eq(new Set(catalog.topics.map(r=>r.subtopic)).size,3);eq(JSON.stringify(catalog).includes('PRIVATE'),false);
 // Exact lesson + subtopic union, domain intersection and difficulty intersection.
 let b=await call('create',u,'sat',id(900),{...setting,section:'Algebra',subtopics:[{topic:topics[0],subtopic:'First skill'}],count:10},null);
 eq(b.question_ids.length,10);eq(new Set(b.question_ids).size,10);eq(b.questions.every(q=>q.topic===topics[0]&&q.difficulty==='medium'),true);
 const saved=(await db.query('select * from practice_bundles order by id')).rows;
 eq(b.questions.some(q=>'correct'in q||'explanation'in q),false);
 let mixed=await call('create',u,'sat',id(901),{...setting,topics:[topics[1]],subtopics:[{topic:topics[0],subtopic:'First skill'}],count:40},null);eq(mixed.questions.length,40);
 eq((await call('create',u,'sat',id(902),{...setting,section:'Algebra',subtopics:[{topic:topics[1],subtopic:'First skill'}]},null)).available,0);
 eq((await call('create',u,'sat',id(903),{...setting,topics:[topics[0]],difficulty:'hard',count:10},null)).questions.every(q=>q.difficulty==='hard'),true);
 // Historical answers from each source, with other users and blank responses excluded.
 await db.query('insert into attempts values($1,$2,88),($3,$4,77)',[id(1e4),u,id(1e4+1),other]);
 await db.query(`insert into attempt_answers values($1,$2,'"A"'),($1,$3,'"  "'),($4,$5,'"B"')`,[id(1e4),id(100),id(106),id(1e4+1),id(107)]);
 for(const [j,t] of ['daily_progress','practice_drills','revision_sessions'].entries())await db.query('insert into '+t+' values($1,$2)',[u,JSON.stringify({[id(101+j)]:'A',[id(108+j)]:''})]);
 await db.query('insert into practice_notebook values($1,$2,1),($1,$3,0)',[u,id(104),id(111)]);
 const bundleQuestion=b.question_ids.find(q=>![101,102,103,104].map(id).includes(q));
 await call('save',u,'sat',b.id,0,{[bundleQuestion]:'A'},0,false);
 catalog=await call('catalog',u,'sat');eq(catalog.topics.reduce((n,r)=>n+r.unseen,0),114);
 const all=await call('create',u,'sat',id(904),{...setting,count:100},null);
 eq(all.questions.length,100);eq(new Set(all.question_ids).size,100);eq(all.question_ids.some(q=>[100,101,102,103,104].map(id).concat(bundleQuestion).includes(q)),false);
 const inclusive=await call('create',u,'sat',id(905),{...setting,section:'Algebra',count:30,exclude_answered:false},null);eq(inclusive.questions.length,30);
 const beforeShort=await one('select count(*)::int from practice_bundles');
 eq((await call('create',u,'sat',id(906),{...setting,section:'Algebra',count:30},null)).available,24);
 eq(await one('select count(*)::int from practice_bundles'),beforeShort);
 eq((await call('create',u,'sat',id(907),{...setting,subtopics:[{topic:topics[0],subtopic:'Missing tag'}],count:1},null)).available,0);
 // No clamping, invalid JSON and other-course subtopics fail before creating work.
 for(const [j,extra] of [{count:0},{count:101},{count:1.2},{subtopics:null},{subtopics:[42]},{subtopics:[{topic:topics[0]}]}].entries())await reject('select public.practice_bundle_create($1,$2,$3,$4,null)',[u,'sat',id(950+j),JSON.stringify({...setting,...extra})],/invalid_/);
 await reject('select public.practice_bundle_create($1,$2,$3,$4,null)',[u,'est',id(960),JSON.stringify({...setting,subtopics:[{topic:topics[0],subtopic:42}]})],/invalid_subtopics/);
 // Metadata updates follow source edits; unknown or supplementary SAT topics stay out.
 await db.query('update questions set assets=assets||$2::jsonb where id=$1',[id(112),JSON.stringify({lesson_subtopic:'Updated skill'})]);
 eq(await one('select subtopic from portal_private.bundle_subtopics where question_id=$1',[id(112)]),'Updated skill');
 await db.query("update questions set topic='Complex numbers' where id=$1",[id(113)]);
 eq((await call('catalog',u,'sat')).topics.reduce((n,r)=>n+r.total,0),119);
 // Holds, reserves, deleted keys and malformed visuals affect counts AND creation.
 await db.query('insert into question_catalogue values($1,true)',[id(114)]);
 await db.query('update questions set assets=assets||$2::jsonb where id=$1',[id(115),JSON.stringify({release_hold_reason:'review'})]);
 await db.query('delete from question_keys where question_id=$1',[id(116)]);
 await db.query('update questions set assets=assets||$2::jsonb where id=$1',[id(117),JSON.stringify({figure_required:true})]);
 eq((await call('catalog',u,'sat')).topics.reduce((n,r)=>n+r.total,0),115);
 const result=await call('create',u,'sat',id(961),{...setting,count:100},null);eq(result.question_ids.some(q=>[113,114,115,116,117].map(id).includes(q)),false);
 // Non-SAT sections are preserved, now with nested subtopics too.
 for(const t of tracks.filter(t=>t!=='sat')){eq(await one('select portal_private.bundle_section($1,$2)',[t,'Triangles and similarity']),t.endsWith('_eng')?'English skills':'Geometry');eq((await call('catalog',u,t)).subtopics_supported,true);}
 // Identical controls work for every other course and every group, without
 // weakening enrollment or sharing another student's answer history.
 await db.exec('create table groups(id uuid primary key,track_id text);create table group_members(group_id uuid,user_id uuid);');
 for(const [ti,t] of tracks.filter(t=>t!=='sat').entries()){
  const learner=id(20000+ti*100),peer=id(20001+ti*100),qnum=30000+ti*100;
  const lesson=t.endsWith('_eng')?'SEC · Subject–verb agreement':t==='act2'?'Matrices':'Triangles and similarity';
  const section=t.endsWith('_eng')?'Standard English conventions':t==='act2'?'Additional mathematics':'Geometry';
  const subtopic=t.endsWith('_eng')?'Singular subjects':t==='act2'?'Matrix operations':'Right triangles';
  await db.query("insert into profiles(id,role,is_test) values($1,'student',true),($2,'student',true)",[learner,peer]);
  await db.query('insert into enrollments(user_id,track_id) values($1,$3),($2,$3)',[learner,peer,t]);
  await db.query('insert into groups values($1,$3),($2,$3)',[id(40000+ti*2),id(40001+ti*2),t]);
  await db.query('insert into group_members values($1,$3),($2,$4),($2,$3)',[id(40000+ti*2),id(40001+ti*2),learner,peer]);
  for(let i=0;i<12;i++){
   const assets={verified_release:'fixture',...(i===10?{}:{lesson_subtopic:i<6||i===11?subtopic:'Other skill'}),...(i===11?{release_hold_reason:'review'}:{})};
   await db.query('insert into questions values($1,$2,$3,$4,\'mcq\',\'Synthetic all-course question\',$5,$6)',[id(qnum+i),t,i===8||i===9?'Systems of equations':lesson,'medium',choices,JSON.stringify(assets)]);
   await db.query('insert into question_keys values($1,\'"A"\',\'Worked solution\')',[id(qnum+i)]);
  }
  const focus={...setting,section,difficulty:'medium',subtopics:[{topic:lesson,subtopic}],count:6};
  const cat=await call('catalog',learner,t),row=cat.topics.find(r=>r.topic===lesson&&r.subtopic===subtopic);
  eq(cat.subtopics_supported,true);eq(row.section,section);eq(row.total,6);eq(row.unseen,6);
  eq(cat.topics.reduce((n,r)=>n+r.total,0),11);
  eq(cat.topics.some(r=>r.topic===lesson&&r.subtopic==='General lesson practice'&&r.total===1),true);
  const created=await call('create',learner,t,id(50000+ti*10),focus,null);
  eq([...created.question_ids].sort(),Array.from({length:6},(_,i)=>id(qnum+i)).sort());
  eq(created.questions.every(q=>q.topic===lesson&&q.difficulty==='medium'),true);
  await db.query('insert into attempts values($1,$2,77)',[id(60000+ti),learner]);
  await db.query('insert into attempt_answers values($1,$2,\'"A"\')',[id(60000+ti),id(qnum)]);
  await db.query('insert into practice_notebook values($1,$2,1)',[learner,id(qnum+1)]);
  for(const [j,table] of ['daily_progress','practice_drills','revision_sessions'].entries())await db.query('insert into '+table+' values($1,$2)',[learner,JSON.stringify({[id(qnum+2+j)]:'B',[id(qnum+8)]:''})]);
  await call('save',learner,t,created.id,0,{[id(qnum+5)]:'A'},0,false);
  const after=await call('catalog',learner,t);
  eq(after.topics.find(r=>r.topic===lesson&&r.subtopic===subtopic).unseen,0);
  eq(after.topics.reduce((n,r)=>n+r.unseen,0),5);
  const before=await one('select count(*)::int from practice_bundles');
  eq((await call('create',learner,t,id(50001+ti*10),focus,null)).available,0);
  eq(await one('select count(*)::int from practice_bundles'),before);
  const peerBundle=await call('create',peer,t,id(50002+ti*10),focus,null);eq(peerBundle.questions.length,6);
  eq((await call('create',learner,t,id(50003+ti*10),{...focus,exclude_answered:false},null)).questions.length,6);
  await reject('select public.practice_bundle_catalog($1,$2)',[learner,'sat'],/not_enrolled/);
  await reject('select public.practice_bundle_state($1,$2,$3)',[peer,t,created.id],/bundle_not_found/);
  const answers=Object.fromEntries(created.question_ids.map(q=>[q,'A']));
  eq((await call('save',learner,t,created.id,1,answers,0,true)).score,6);
  const retake=await call('create',learner,t,id(50004+ti*10),{},created.id);
  eq(retake.question_ids,created.question_ids);eq(retake.answers,{});
  eq((await call('state',learner,t,created.id)).score,6);
  eq(await one('select score from attempts where id=$1',[id(60000+ti)]),77);
  await db.query('update questions set assets=assets||\'{"lesson_subtopic":"Updated course skill"}\'::jsonb where id=$1',[id(qnum+6)]);
  eq((await call('catalog',learner,t)).topics.some(r=>r.subtopic==='Updated course skill'),true);
 }
 // No writes to exam scores, and saved bundle snapshots/answers remain versioned.
 eq(await one('select score from attempts where id=$1',[id(1e4)]),88);
 eq((await call('state',u,'sat',b.id)).answers,{[bundleQuestion]:'A'});
 eq((await call('state',u,'sat',b.id)).question_ids,b.question_ids);
 for(const role of ['anon','authenticated']){await db.exec('set role '+role);await reject('select * from portal_private.bundle_subtopics',[],/permission denied/);await reject('select public.practice_bundle_catalog($1,$2)',[u,'sat'],/permission denied/);await db.exec('reset role');}
 await db.exec('set role service_role');eq((await call('catalog',u,'sat')).track,'sat');await db.exec('reset role');
 // Guard rejects accidental replay or later definition drift.
 await assert.rejects(()=>db.exec(read('supabase/sql/practice_bundle_hierarchy.sql')),/Changed since review/);checks++;
 await db.close();console.log(checks+' all-course hierarchy database assertions passed.');
})().catch(e=>{console.error(e);process.exit(1)});
