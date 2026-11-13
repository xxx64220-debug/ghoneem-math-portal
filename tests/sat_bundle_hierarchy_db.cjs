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
 await db.exec(read('supabase/sql/sat_bundle_hierarchy.sql'));
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
 await reject('select public.practice_bundle_create($1,$2,$3,$4,null)',[u,'est',id(960),JSON.stringify({...setting,subtopics:[{topic:topics[0],subtopic:'First skill'}]})],/invalid_subtopics/);
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
 // All non-SAT sections retain their prior behavior.
 for(const t of tracks.filter(t=>t!=='sat')){eq(await one('select portal_private.bundle_section($1,$2)',[t,'Triangles and similarity']),t.endsWith('_eng')?'English skills':'Geometry');eq((await call('catalog',u,t)).subtopics_supported,false);}
 // No writes to exam scores, and saved bundle snapshots/answers remain versioned.
 eq(await one('select score from attempts where id=$1',[id(1e4)]),88);
 eq((await call('state',u,'sat',b.id)).answers,{[bundleQuestion]:'A'});
 eq((await call('state',u,'sat',b.id)).question_ids,b.question_ids);
 for(const role of ['anon','authenticated']){await db.exec('set role '+role);await reject('select * from portal_private.bundle_subtopics',[],/permission denied/);await reject('select public.practice_bundle_catalog($1,$2)',[u,'sat'],/permission denied/);await db.exec('reset role');}
 await db.exec('set role service_role');eq((await call('catalog',u,'sat')).track,'sat');await db.exec('reset role');
 // Guard rejects accidental replay or later definition drift.
 await assert.rejects(()=>db.exec(read('supabase/sql/sat_bundle_hierarchy.sql')),/Changed since review/);checks++;
 await db.close();console.log(checks+' SAT hierarchy database assertions passed.');
})().catch(e=>{console.error(e);process.exit(1)});
