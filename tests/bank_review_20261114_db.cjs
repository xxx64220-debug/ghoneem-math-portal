// Disposable PostgreSQL only. Never connects to the live portal.
const {PGlite}=require(process.env.PGLITE_MODULE||'@electric-sql/pglite');
const fs=require('node:fs'),assert=require('node:assert/strict');
const dir='content-releases/20261114_bank_review/',load=n=>JSON.parse(fs.readFileSync(dir+n+'.json','utf8'));
const supported=process.env.BANK_REVIEW_PHASE==='supported',suffix=supported?'_supported':'';
const db=new PGlite(); let checks=0;
const ok=(v,m)=>{assert.ok(v,m);checks++},eq=(a,b,m)=>{assert.deepEqual(a,b,m);checks++};
const scalar=async(q,p=[])=>Object.values((await db.query(q,p)).rows[0])[0];
async function main(){
 await db.exec(`create role anon; create role authenticated; create role service_role;
 create table questions(id uuid primary key,track_id text,topic text,difficulty text,type text,stem text,choices jsonb,assets jsonb,created_at timestamptz default now());
 create table question_keys(question_id uuid primary key references questions(id),correct jsonb,explanation text);
 create table exams(id uuid primary key,track_id text,question_ids uuid[],is_published boolean);
 create table attempts(id uuid primary key,exam_id uuid,status text,score int);
 create table attempt_answers(attempt_id uuid,question_id uuid,response jsonb);
 create table attempt_results(attempt_id uuid,question_id uuid,correct boolean,points int);
 create table assignments(id int,exam_id uuid,group_id int);
 create table revision_sessions(id int,snapshot jsonb,answers jsonb);
 create table practice_bundle_items(id int,question_id uuid,response jsonb);
 create table practice_notebook(question_id uuid,payload jsonb);`);
 await db.exec(fs.readFileSync('supabase/sql/question_eligibility_core.sql','utf8'));
 const pool=new Map([...load('full_candidates'),...load('full_repairs'),...load('existing_cylinder'),...(supported?[...load('supported_before'),...load('supported_extra_before')]:[])].map(q=>[q.id,q]));
 for(const q of pool.values()){
  const {key_row,row_hash,key_hash,...fields}=q;
  await db.query('insert into questions select (jsonb_populate_record(null::questions,$1::jsonb)).*',[JSON.stringify(fields)]);
  await db.query('insert into question_keys values($1,$2::jsonb,$3)',[q.id,JSON.stringify(key_row.correct),key_row.explanation]);
 }
 const untouched='00000000-0000-4000-8000-000000000001',eid='00000000-0000-4000-8000-000000000002',aid='00000000-0000-4000-8000-000000000003';
 await db.query(`insert into questions values($1,'est2','Unchanged','medium','grid_in','Unchanged scored fixture','[]','{}',now())`,[untouched]);
 await db.query(`insert into question_keys values($1,'"2"','Fixture')`,[untouched]);
 await db.query('insert into exams values($1,$2,$3,true)',[eid,'est2',[untouched]]);
 await db.query("insert into attempts values($1,$2,'graded',17)",[aid,eid]);
 await db.query("insert into attempt_answers values($1,$2,'\"2\"')",[aid,untouched]);
 await db.query('insert into attempt_results values($1,$2,true,1)',[aid,untouched]);
 await db.query('insert into assignments values(1,$1,1)',[eid]);
 await db.query('insert into revision_sessions values(1,$1::jsonb,$2::jsonb)',[JSON.stringify({questions:[pool.values().next().value]}),JSON.stringify({old:'saved answer'})]);
 await db.query("insert into practice_bundle_items values(1,$1,'\"2\"');",[untouched]);
 await db.query("insert into practice_notebook values($1,'{\"mistakes\":3}')",[untouched]);
 const tables=['attempts','attempt_answers','attempt_results','exams','assignments','revision_sessions','practice_bundle_items','practice_notebook'];
 const history=async()=>Object.fromEntries(await Promise.all(tables.map(async t=>[t,(await db.query('select * from '+t)).rows])));
 const savedHistory=await history(),correctBefore=(await db.query('select question_id,correct from question_keys order by question_id')).rows;
 const m=load('manifest'+suffix);
 for(const p of m.updates){
  p.row_hash=await scalar('select md5(to_jsonb(q)::text) from questions q where id=$1',[p.id]);
  p.key_hash=await scalar('select md5(to_jsonb(k)::text) from question_keys k where question_id=$1',[p.id]);
 }
 let sql=fs.readFileSync(dir+'apply'+suffix+'.sql','utf8');
 sql=sql.replace(/data_ jsonb := '(?:[^']|'')*'::jsonb;/,'data_ jsonb := \''+JSON.stringify(m).replaceAll("'","''")+'\'::jsonb;');
 const countBefore=await scalar('select count(*) from questions');
 // A late change to either the question or its key must reject the entire release.
 const last=m.updates.at(-1),old=pool.get(last.id);
 await db.query("update questions set stem=stem||' concurrent' where id=$1",[last.id]);
 await assert.rejects(()=>db.exec(sql),/Concurrent content change/);checks++;await db.exec('rollback');
 eq(await scalar('select count(*) from questions'),countBefore);
 eq(await history(),savedHistory);
 await db.query('update questions set stem=$2 where id=$1',[last.id,old.stem]);
 await db.query("update question_keys set explanation=explanation||' concurrent' where question_id=$1",[last.id]);
 await assert.rejects(()=>db.exec(sql),/Concurrent content change/);checks++;await db.exec('rollback');
 await db.query('update question_keys set explanation=$2 where question_id=$1',[last.id,old.key_row.explanation]);
 // Guard the newly clarified question against a late student answer.
 const clarified='df2132af-840a-501e-9268-3a64a7d75791';
 await db.query("insert into attempt_answers values($1,$2,'\"D\"')",[aid,clarified]);
 await assert.rejects(()=>db.exec(sql),/New answers require/);checks++;await db.exec('rollback');
 await db.query('delete from attempt_answers where question_id=$1',[clarified]);
 // A hidden prior adaptation also blocks duplicates even with a different UUID.
 await db.query("update questions set assets=jsonb_build_object('source_ids_adapted',$2::jsonb) where id=$1",[untouched,JSON.stringify(m.additions[0].assets.source_ids_adapted)]);
 await assert.rejects(()=>db.exec(sql),/Source already has an adaptation/);checks++;await db.exec('rollback');
 await db.query("update questions set assets='{}' where id=$1",[untouched]);
 await db.exec(sql);
 eq(await scalar('select count(*) from questions'),Number(countBefore)+m.additions.length);
 eq(await history(),savedHistory,'No exam, assignment, score, notebook, or saved-session writes');
 eq((await db.query('select question_id,correct from question_keys where question_id=any($1::uuid[]) order by question_id',[correctBefore.map(k=>k.question_id)])).rows,correctBefore,'All pre-existing accepted answers remain identical');
 for(const q of (supported?[]:load('unreleased'))){
  ok(await scalar('select portal_private.question_eligible(q,k,q.track_id,false) and q.assets->>\'verified_release\'=$2 from questions q join question_keys k on k.question_id=q.id where q.id=$1',[q.id,m.release]),q.id);
 }
 for(const q of m.additions){
  ok(await scalar("select portal_private.question_eligible(q,k,'act2',false) from questions q join question_keys k on k.question_id=q.id where q.id=$1",[q.id]),q.id);
  eq(await scalar("select portal_private.question_eligible(q,k,'est',false) from questions q join question_keys k on k.question_id=q.id where q.id=$1",[q.id]),false,'ACT content does not leak into EST');
  for(const source of q.assets.source_ids_adapted){
   eq(await scalar('select portal_private.question_eligible(q,k,q.track_id,false) from questions q join question_keys k on k.question_id=q.id where q.id=$1',[source]),false,'Defective original stays held');
   eq(await scalar("select assets->>'replacement_question_id' from questions where id=$1",[source]),q.id);
  }
 }
 if(!supported)for(const q of load('full_repairs').filter(q=>q.track_id==='sat'))eq(await scalar("select assets ? 'figure' from questions where id=$1",[q.id]),false,'Unrelated cover removed');
 const committed=await scalar('select count(*) from questions');
 await assert.rejects(()=>db.exec(sql),/Concurrent content change/);checks++;await db.exec('rollback');
 eq(await scalar('select count(*) from questions'),committed,'Reapplying cannot duplicate releases');
 if(!supported){
  await db.exec(`create table revision_items(question_id uuid primary key,lesson text,idea text,difficulty text,programmes text[],fingerprint text,active boolean,focus jsonb);
   create table question_catalogue(question_id uuid primary key,reserve boolean);
   create function revision_question_fingerprint(p_stem text,p_choices jsonb,p_assets jsonb,p_correct jsonb,p_explanation text) returns text language sql immutable as $$select md5(jsonb_build_array(p_stem,p_choices,coalesce(p_assets,'{}'::jsonb)-'curriculum_lesson'-'lesson_subtopic'-'lesson_original_topic'-'lesson_taxonomy_version',p_correct,p_explanation)::text)$$;`);
  const syncRows=load('revision_sync_before');
  for(const p of syncRows){
   await db.query('insert into revision_items select (jsonb_populate_record(null::revision_items,$1::jsonb)).*',[JSON.stringify(p.revision_before)]);
   p.question_hash=await scalar('select md5(to_jsonb(q)::text) from questions q where id=$1',[p.id]);
   p.key_hash=await scalar('select md5(to_jsonb(k)::text) from question_keys k where question_id=$1',[p.id]);
  }
  let syncSql=fs.readFileSync(dir+'sync_final_revision.sql','utf8');
  syncSql=syncSql.replace(/data_ jsonb:='(?:[^']|'')*'::jsonb;/,"data_ jsonb:='"+JSON.stringify(syncRows).replaceAll("'","''")+"'::jsonb;");
  await db.query("update revision_items set idea=idea||' concurrent' where question_id=$1",[syncRows[0].id]);
  await assert.rejects(()=>db.exec(syncSql),/Concurrent revision content change/);checks++;await db.exec('rollback');
  await db.query('update revision_items set idea=$2 where question_id=$1',[syncRows[0].id,syncRows[0].revision_before.idea]);
  await db.exec(syncSql);
  eq(await scalar('select count(*) from revision_items r join questions q on q.id=r.question_id join question_keys k on k.question_id=q.id where r.active and r.lesson=q.topic and r.fingerprint=revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation)'),51);
  eq(await scalar("select topic from questions where id='2574795c-0842-5799-a7a6-9f318be55de6'"),'Angles and lines');
  eq(await scalar("select lesson from revision_items where question_id='38d27545-acab-51b6-8a5a-e5552566ff8c'"),'Inequalities and absolute value');
  eq(await history(),savedHistory,'Catalogue refresh must not mutate saved scores or sessions');
 }
 console.log(`${checks} database checks passed`);
 await db.close();
}
main().catch(e=>{console.error(e.message,e.detail||'',e.where||'');process.exit(1)});
