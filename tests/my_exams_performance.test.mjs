import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {PGlite} from './device-runtime/node_modules/@electric-sql/pglite/dist/index.js';
const captured=JSON.parse(readFileSync('security-releases/20261030-portal-followup/functions-before.json','utf8'));
const def=name=>captured.find(x=>x.proname===name).definition;
const id=n=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const normalized=a=>a.sort((x,y)=>x.id.localeCompare(y.id));

test('optimized catalog preserves assignments, readiness, access windows, history and retakes',async()=>{
 const db=new PGlite();let comparisons=0;
 try{
  await db.exec(`
   create role anon;create role authenticated;create role service_role;
   create schema portal_private;
   create table profiles(id uuid primary key,role text,status text);
   create table tracks(id text primary key,is_active boolean);
   create table enrollments(user_id uuid,track_id text,status text,starts_at timestamptz,ends_at timestamptz);
   create table group_members(group_id uuid,user_id uuid);
   create table questions(id uuid primary key,track_id text,type text,stem text,choices jsonb,assets jsonb);
   create table question_keys(question_id uuid primary key,correct jsonb,explanation text);
   create table exams(id uuid primary key,track_id text,title text,duration_seconds int,question_ids uuid[],
    assessment_type text,exam_set_code text,module_number int,module_count int,created_at timestamptz,is_published boolean);
   create table assignments(id uuid primary key,exam_id uuid,group_id uuid,user_id uuid,open_at timestamptz,close_at timestamptz);
   create table attempts(id uuid primary key,user_id uuid,exam_id uuid,attempt_no int,status text,started_at timestamptz,deadline_at timestamptz,
    review_unlocks_at timestamptz,score int,total int,scaled_score int);
   create table retake_grants(user_id uuid,exam_id uuid,consumed_at timestamptz,expires_at timestamptz);
   insert into tracks values('est',true),('sat',true),('inactive',false);
   insert into profiles values('${id(1)}','student','active'),('${id(2)}','student','active'),('${id(3)}','student','suspended');
   insert into enrollments values('${id(1)}','est','active',null,null),('${id(2)}','est','active',null,now()-interval '1 hour'),('${id(3)}','est','active',null,null);
   insert into group_members values('${id(10)}','${id(1)}'),('${id(11)}','${id(2)}');
  `);
  for(const name of ['is_enrolled','attempt_course_access','question_eligible','exam_content_ready','student_assignment_for'])await db.exec(def(name));
  await db.exec(def('my_exams').replace('public.my_exams(','public.my_exams_before('));
  // PostgreSQL's JIT setting is not compiled into PGlite; production keeps it.
  await db.exec(readFileSync('supabase/sql/my_exams_performance.sql','utf8').replace(/^SET jit TO off\n/m,''));
  await db.exec('revoke all on function public.my_exams(uuid,text) from public,anon,authenticated; grant execute on function public.my_exams(uuid,text) to service_role;');
  const choices=JSON.stringify(['A','B','C','D'].map((key,i)=>({key,text:String(i+1)})));
  for(let n=100;n<106;n++){
   await db.query('insert into questions values($1,$2,$3,$4,$5,$6)',[id(n),n===104?'sat':'est',n===105?'grid_in':'mcq','A complete question',choices,JSON.stringify(n===101?{release_hold_reason:'review'}:n===103?{bank_removed:true}:{})]);
   if(n!==102)await db.query('insert into question_keys values($1,$2,$3)',[id(n),JSON.stringify(n===105?[4]:'A'),'Worked solution']);
  }
  const sets=[[id(100)],[id(101)],[id(102)],[id(103)],[id(104)],[id(105)],[],null,[id(100),id(100)],[id(999)],[null],Array(201).fill(id(100))];
  for(let i=0;i<sets.length;i++){
   const e=id(200+i);
   await db.query(`insert into exams values($1,'est',$2,1200,$3,$4,null,null,null,now()+($5||' seconds')::interval,true)`,[e,'Exam '+i,sets[i],i%2?'quiz':'lesson_exam',String(i)]);
   await db.query('insert into assignments values($1,$2,$3,null,null,null)',[id(300+i),e,id(10)]);
  }
  // Duplicate recipients, future starts, past closes and current boundaries.
  await db.query('insert into assignments values($1,$2,null,$3,null,null)',[id(350),id(200),id(1)]);
  await db.exec(`update assignments set open_at=now()+interval '1 day' where exam_id='${id(205)}';
   update assignments set close_at=now()-interval '1 day' where exam_id='${id(201)}';
   insert into exams values('${id(250)}','sat','Other course',1200,array['${id(104)}']::uuid[],'quiz',null,null,null,now(),true);
   insert into assignments values('${id(351)}','${id(250)}',null,'${id(1)}',null,null);
   insert into exams select '${id(251)}',track_id,'Unassigned',duration_seconds,question_ids,assessment_type,null,null,null,now(),true from exams where id='${id(200)}';
   insert into exams select '${id(252)}',track_id,'Unpublished',duration_seconds,question_ids,assessment_type,null,null,null,now(),false from exams where id='${id(200)}';
   insert into assignments values('${id(352)}','${id(252)}',null,'${id(1)}',null,null);
   insert into attempts values('${id(400)}','${id(1)}','${id(200)}',1,'graded',now()-interval '2 hours',now()-interval '1 hour',now(),1,1,800),
    ('${id(401)}','${id(1)}','${id(200)}',2,'in_progress',now(),'infinity',null,null,1,null),
    ('${id(402)}','${id(2)}','${id(200)}',1,'in_progress',now()-interval '2 hours',now()+interval '30 minutes',null,null,1,null);
   insert into assignments values('${id(353)}','${id(200)}','${id(11)}',null,null,null);
   insert into retake_grants values('${id(1)}','${id(201)}',null,now()+interval '1 day'),('${id(1)}','${id(203)}',now(),null),('${id(1)}','${id(205)}',null,now()-interval '1 day');
  `);
  async function compare(){for(const user of [id(1),id(2),id(3),id(999)])for(const track of ['est','sat','inactive',null]){
   const {rows:[r]}=await db.query('select public.my_exams_before($1,$2) old,public.my_exams($1,$2) actual',[user,track]);
   assert.deepEqual(normalized(r.actual),normalized(r.old),`${user} / ${track}`);comparisons++;
  }}
  await compare();
  await db.exec(`update enrollments set starts_at=now()+interval '1 day' where user_id='${id(1)}';`);await compare();
  await db.exec(`update enrollments set starts_at=null;update tracks set is_active=false where id='est';`);await compare();
  await db.exec(`update tracks set is_active=true;update questions set assets='{"figure_required":true}' where id='${id(100)}';`);await compare();
  for(const role of ['anon','authenticated'])await assert.rejects(()=>db.transaction(async tx=>{await tx.exec('set local role '+role);await tx.query('select public.my_exams($1,$2)',[id(1),'est']);}),/permission denied/);
  assert.equal(comparisons,64);
 }finally{await db.close();}
});
