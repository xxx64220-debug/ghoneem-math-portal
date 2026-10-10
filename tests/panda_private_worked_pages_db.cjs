// Local PostgreSQL WASM only: synthetic images and no production connection.
const {PGlite}=require(process.env.PGLITE_MODULE||'@electric-sql/pglite');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'),read=f=>fs.readFileSync(path.join(root,f),'utf8');
const db=new PGlite(),id=n=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
const user=id(1),other=id(2),session=id(3),image='data:image/jpeg;base64,QUJD';
const scalar=async(sql,args=[])=>Object.values((await db.query(sql,args)).rows[0])[0];
const state=()=>scalar('select final_revision_state($1,$2,$3)',[user,'sat',session]);
async function main(){
 await db.exec(read('tests/00_shim.sql').replace(/create extension if not exists pgcrypto;/g,''));
 await db.exec(read('supabase/migrations/001_schema.sql').replace(/create extension if not exists pgcrypto;/g,''));
 await db.exec(`create table portal_track_controls(track_id text primary key,revision_visible boolean default true);
 create table revision_items(question_id uuid primary key references questions(id),lesson text,idea text,difficulty text,programmes text[],fingerprint text,focus jsonb default '{}',active boolean default true);
 create table revision_sessions(id uuid primary key default gen_random_uuid(),user_id uuid,access_track text,lesson text,collection text default 'all',snapshot jsonb,answers jsonb default '{}',created_at timestamptz default now(),completed_at timestamptz);
 create function norm_num(t text) returns numeric language sql immutable as $$select case when t ~ '^-?[0-9]+$' then t::numeric else null end$$;`);
 // Existing readback fixture supplies enrollment/scoring/fingerprint helpers.
 await db.exec(read('tests/fixtures/oct4-support-functions.sql'));
 const fixtureState=await scalar("select pg_get_functiondef('final_revision_state(uuid,text,uuid)'::regprocedure)");
 await db.exec(read('supabase/sql/panda_private_worked_pages.sql'));
 assert.equal(await scalar("select pg_get_functiondef('final_revision_state(uuid,text,uuid)'::regprocedure)"),fixtureState,'Canonical function matches the already-live October 4 readback');
 assert.equal(await scalar('select count(*)::int from panda_solution_pages'),0,'Schema support imports no images');
 await db.exec(`insert into auth.users(id) values('${user}'),('${other}');insert into profiles(id) values('${user}'),('${other}');
 insert into tracks(id,name) values('sat','SAT'),('est','EST I'),('est2','EST II');
 insert into enrollments(user_id,track_id) select u.id,t.id from auth.users u cross join tracks t;
 insert into portal_track_controls(track_id) select id from tracks;`);
 await db.query('insert into panda_solution_pages values(365,$1)',[image]);
 const snapshot=[];
 for(const [n,track,page] of [[10,'sat',365],[11,'sat',365],[12,'est',null],[13,'est2',null]]){
  const qid=id(n),assets={figure:image,...(page?{solution_page:page,source_number:n}:{} )};
  await db.query("insert into questions(id,track_id,topic,stem,choices,assets) values($1,$2,'Algebra','Synthetic prompt',$3::jsonb,$4::jsonb)",[qid,track,JSON.stringify([{key:'A',text:'1'},{key:'B',text:'2'}]),JSON.stringify(assets)]);
  await db.query("insert into question_keys values($1,'\"A\"','PRIVATE EXPLANATION')",[qid]);
  await db.query("insert into revision_items select q.id,'Algebra','Synthetic idea','medium',array[q.track_id],revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation),'{\"collections\":[\"unique\"],\"takeaway\":\"PRIVATE HINT\"}',true from questions q join question_keys k on k.question_id=q.id where q.id=$1",[qid]);
  snapshot.push({id:qid,source:track,type:'mcq',assets:{figure:image},correct:'A',explanation:'PRIVATE EXPLANATION',fingerprint:'PRIVATE FINGERPRINT',focus:{takeaway:'PRIVATE HINT'}});
 }
 await db.query('insert into revision_sessions(id,user_id,access_track,snapshot) values($1,$2,$3,$4::jsonb)',[session,user,'sat',JSON.stringify(snapshot)]);
 let result=await state();
 assert.equal(result.questions.length,3,'SAT allows SAT + EST I, excludes EST II');
 assert.doesNotMatch(JSON.stringify(result),/solution_figure|solution_page|PRIVATE/);
 await db.query('update revision_sessions set answers=$1::jsonb where id=$2',[JSON.stringify({[id(10)]:'B'}),session]);
 result=await state();
 assert.equal(result.questions[0].assets.solution_figure,image,'A checked wrong answer also unlocks the worked page');
 assert.equal(result.questions[0].assets.source_number,10);
 assert.equal(result.questions[0].feedback.correct,false);
 assert.equal(result.questions[1].assets.solution_figure,undefined,'Unchecked question remains hidden, even on the same answer page');
 assert.equal(result.completed,false);
 await assert.rejects(()=>scalar('select final_revision_state($1,$2,$3)',[other,'sat',session]),/revision_session_not_found/);
 await assert.rejects(()=>scalar('select final_revision_state($1,$2,$3)',[user,'est',session]),/revision_session_not_found/);
 await db.exec("update portal_track_controls set revision_visible=false where track_id='sat'");
 await assert.rejects(state,/revision_hidden/);
 await db.exec("update portal_track_controls set revision_visible=true;update enrollments set status='paused' where track_id='sat'");
 await assert.rejects(state,/not_enrolled_in_track/);
 await db.exec("update enrollments set status='active'");
 for(const role of ['anon','authenticated']){
  await db.exec('set role '+role);
  await assert.rejects(()=>db.query('select * from panda_solution_pages'),/permission denied/);
  await assert.rejects(state,/permission denied for function/);
  await db.exec('reset role');
 }
 assert.equal(await scalar("select relrowsecurity from pg_class where oid='panda_solution_pages'::regclass"),true);
 assert.equal(await scalar("select prosecdef from pg_proc where oid='final_revision_state(uuid,text,uuid)'::regprocedure"),false);
 await assert.rejects(()=>db.query('insert into panda_solution_pages values(500,$1)',[image]),/check constraint/);
 await assert.rejects(()=>db.query("insert into panda_solution_pages values(366,'https://public.example/answer.jpg')"),/check constraint/);
 // Execute the current catalogue/start/answer implementation, not the old PR's.
 const eligibility=read('supabase/sql/question_eligibility.sql');
 await db.exec(eligibility.slice(eligibility.indexOf('create schema if not exists portal_private'),eligibility.indexOf('CREATE OR REPLACE FUNCTION public.new_exam')));
 await db.exec(eligibility.slice(eligibility.indexOf('CREATE OR REPLACE FUNCTION public.final_revision('),eligibility.lastIndexOf('commit;')));
 await db.exec('revoke all on revision_sessions,revision_items from public,anon,authenticated;grant all on revision_sessions,revision_items to service_role;grant select on questions,question_keys,portal_track_controls,profiles to service_role;revoke all on function final_revision(uuid,text,text,jsonb) from public,anon,authenticated;grant execute on function final_revision(uuid,text,text,jsonb) to service_role;');
 await db.exec('set role service_role');
 const call=(action,options={})=>scalar('select final_revision($1,$2,$3,$4::jsonb)',[user,'sat',action,JSON.stringify(options)]);
 const catalogue=await call('catalogue');
 assert.doesNotMatch(JSON.stringify(catalogue.items),/assets|correct|explanation|PRIVATE|solution_/);
 const started=await call('start',{count:'10',collection:'all',scope:'both'});
 assert.equal(started.questions.length,3);
 assert.doesNotMatch(JSON.stringify(started),/solution_figure|solution_page|PRIVATE/);
 const saved=await scalar('select snapshot from revision_sessions where id=$1',[started.id]);
 assert.doesNotMatch(JSON.stringify(saved),/solution_figure|solution_page/,'Private pages never enter the persisted prompt snapshot');
 const checked=await call('answer',{session:started.id,question:id(10),answer:'A'});
 assert.equal(checked.questions.find(q=>q.id===id(10)).assets.solution_figure,image);
 assert.deepEqual(await call('answer',{session:started.id,question:id(10),answer:'B'}),checked,'Checked answer stays immutable');
 await db.exec('reset role');
 const before=(await db.query('select * from questions order by id')).rows;
 await db.exec(read('supabase/sql/panda_private_worked_pages.sql'));
 assert.deepEqual((await db.query('select * from questions order by id')).rows,before,'Support replay does not rewrite questions');
 assert.equal(await scalar('select count(*)::int from panda_solution_pages'),1);
 console.log('PASS: canonical live-state parity; current catalogue/start/answer; private table and RPC permissions; checked-only reveal; keyless catalogue; prompt snapshots; ownership, track, visibility, enrollment, constraints and import-free replay.');
 await db.close();
}
main().catch(async e=>{console.error(e.message);await db.close();process.exitCode=1;});
