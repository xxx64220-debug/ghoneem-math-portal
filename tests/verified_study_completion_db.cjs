const { PGlite } = require('./device-runtime/node_modules/@electric-sql/pglite');
const fs = require('node:fs');
const assert = require('node:assert/strict');

(async () => {
  const db = new PGlite();
  const id = n => '00000000-0000-4000-8000-' + String(n).padStart(12, '0');
  let checks = 0;
  const equal = (actual, expected) => { assert.deepEqual(actual, expected); checks++; };
  const denied = async sql => { await assert.rejects(db.exec(sql)); checks++; };
  const scalar = async sql => Object.values((await db.query(sql)).rows[0])[0];
  await db.exec(`
    create role anon; create role authenticated;
    create schema auth; create schema portal_private;
    create function auth.uid() returns uuid language sql as $$select nullif(current_setting('test.actor', true),'')::uuid$$;
    create function portal_private.current_session_allowed() returns boolean language sql as $$select current_setting('test.approved',true)='yes'$$;
    create function portal_private.staff_can_touch_track(text) returns boolean language sql as $$select current_setting('test.staff',true)='yes' and $1='sat'$$;
    create function portal_private.staff_can_read_student(uuid) returns boolean language sql as $$select current_setting('test.staff',true)='yes' and $1='${id(1)}'::uuid$$;
    grant usage on schema auth,portal_private to authenticated;
    create table profiles(id uuid primary key);
    create table tracks(id text primary key);
    create table exams(id uuid primary key,track_id text);
    create table enrollments(user_id uuid,track_id text);
    create table attempts(id uuid primary key,user_id uuid,exam_id uuid,status text,started_at timestamptz,submitted_at timestamptz,score integer);
    create table attempt_answers(attempt_id uuid,response jsonb);
    grant select on exams,enrollments,attempts,attempt_answers to authenticated;
    alter table attempts enable row level security;
    create policy own_attempts on attempts for select to authenticated using(user_id=auth.uid() or portal_private.staff_can_read_student(user_id));
    insert into profiles values('${id(1)}'),('${id(2)}');
    insert into tracks values('sat'),('est');
    insert into exams values('${id(11)}','sat'),('${id(12)}','sat'),('${id(13)}','est');
    insert into enrollments values('${id(1)}','sat'),('${id(2)}','sat');
  `);
  await db.exec(fs.readFileSync('supabase/migrations/20261102174500_student_daily_objectives.sql','utf8'));
  await db.exec(fs.readFileSync('supabase/sql/personal_study_planner.sql','utf8'));
  await db.exec(`
    insert into student_daily_objectives(user_id,track_id,study_date,title,instructions,time_budget,destination,practice_exam_id)
    values('${id(1)}','sat','2026-11-05','Systems','Solve','30 min','practice','${id(11)}'),
          ('${id(2)}','sat','2026-11-05','Other','Solve','30 min','practice','${id(11)}');
    insert into study_activity_progress values('${id(1)}','sat','2026-11-05','practice','completed');
  `);
  await db.exec(fs.readFileSync('supabase/sql/verified_study_completion.sql','utf8'));
  const actor = async (student=1,staff=false) => db.exec(`set test.actor='${id(student)}'; set test.approved='yes'; set test.staff='${staff?'yes':'no'}'; set role authenticated;`);
  const state = async (activity='practice',date='2026-11-05') => scalar(`select status from study_activity_completion where user_id='${id(1)}' and study_date='${date}' and activity='${activity}'`);
  await actor();
  equal(await scalar('select count(*)::int from study_activity_completion'),3);
  equal(await state(),'pending'); // Old self-report is not submitted evidence.
  equal(await state('lesson'),'needs_link');
  equal(await scalar('select status from study_activity_progress'),'completed'); // History retained.
  await denied(`update study_activity_progress set status='completed'`);
  await denied(`insert into study_activity_progress values('${id(1)}','sat','2026-11-05','lesson','completed')`);
  await denied(`update study_activity_completion set status='completed'`);
  await denied('delete from study_activity_progress');
  const attempt = async (number,{student=1,exam=11,status='in_progress',started='2026-11-05T08:00:00+02',submitted=null,response=null}={}) => {
    await db.exec('reset role');
    await db.query('insert into attempts values($1,$2,$3,$4,$5,$6,0)',[id(number),id(student),id(exam),status,started,submitted]);
    if(response!==null) await db.query('insert into attempt_answers values($1,$2)',[id(number),JSON.stringify(response)]);
    await actor();
  };
  await attempt(21,{student:2,status:'graded',submitted:'2026-11-05T09:00:00+02',response:'A'});
  equal(await state(),'pending');
  await attempt(22,{exam:12,status:'graded',submitted:'2026-11-05T09:00:00+02',response:'A'});
  equal(await state(),'pending');
  await attempt(23,{started:'2026-11-04T21:59:59Z',status:'graded',submitted:'2026-11-05T09:00:00+02',response:'A'});
  equal(await state(),'pending'); // One second before Cairo study date.
  await attempt(24,{status:'expired',submitted:'2026-11-05T09:00:00+02',response:'A'});
  equal(await state(),'pending');
  await attempt(25,{status:'graded',submitted:'2026-11-05T09:00:00+02'});
  equal(await state(),'pending'); // Empty submitted attempt.
  await attempt(26,{status:'graded',submitted:'2026-11-05T09:00:00+02',response:''});
  equal(await state(),'pending');
  await attempt(27,{status:'graded',response:'A'});
  equal(await state(),'pending'); // Missing submission timestamp.
  await attempt(28);
  equal(await state(),'in_progress');
  await db.exec(`reset role; update attempts set status='graded',submitted_at='2026-11-05T09:00:00+02' where id='${id(28)}'; insert into attempt_answers values('${id(28)}','"B"');`);
  await actor();
  equal(await state(),'completed'); // Score zero still counts as submitted work.
  equal(await scalar(`select attempt_id from study_activity_completion where activity='practice'`),id(28));
  await attempt(29,{started:'2026-11-05T10:00:00+02'});
  equal(await state(),'completed'); // A later open retake cannot erase completion.
  await db.exec(`reset role; update student_daily_objectives set lesson_exam_id='${id(11)}',retest_exam_id='${id(13)}' where user_id='${id(1)}';`);
  await actor();
  equal(await state('lesson'),'completed');
  await attempt(30,{exam:13,status:'graded',submitted:'2026-11-05T09:00:00+02',response:'A'});
  equal(await state('retest'),'pending'); // Wrong course cannot count.
  await db.exec(`reset role; insert into student_daily_objectives(user_id,track_id,study_date,title,instructions,time_budget,destination,practice_exam_id) values('${id(1)}','sat','2026-11-07','Repeat','Solve','30 min','practice','${id(11)}');`);
  await actor();
  equal(await state('practice','2026-11-07'),'pending');
  await attempt(31,{started:'2026-11-07T09:00:00+02',status:'graded',submitted:'2026-11-07T10:00:00+02',response:'A'});
  equal(await state('practice','2026-11-07'),'completed');
  equal(await scalar(`select attempt_id from study_activity_completion where activity='practice' and study_date='2026-11-05'`),id(28));
  await db.exec(`reset role; update student_daily_objectives set practice_exam_id='${id(12)}' where user_id='${id(1)}' and study_date='2026-11-07';`);
  await actor();
  equal(await state('practice','2026-11-07'),'pending');
  await attempt(32,{exam:12,started:'2026-11-08T09:00:00+02',status:'submitted',submitted:'2026-11-08T10:00:00+02',response:'C'});
  equal(await state('practice','2026-11-07'),'completed'); // Late completion.
  await db.exec("set test.approved='no'");
  equal(await scalar('select count(*)::int from study_activity_completion'),0);
  await actor(2);
  equal(await scalar('select count(*)::int from study_activity_completion'),3);
  await actor(99,true);
  equal(await scalar('select count(*)::int from study_activity_completion'),6);
  await denied("update study_activity_progress set status='completed'");
  await db.exec('reset role;set role anon');
  await denied('select * from study_activity_completion');
  await db.exec(`reset role;
    create table groups(id uuid primary key,track_id text);
    create table group_members(group_id uuid,user_id uuid);
    create table daily_progress(user_id uuid,track_id text,day date,quiz_group_id uuid,quiz_started_at timestamptz,quiz_completed_at timestamptz);
    alter table daily_progress enable row level security;
    grant select on groups,group_members to authenticated;
    update student_daily_objectives set retest_exam_id=null where track_id='sat';
    insert into groups values('${id(70)}','sat'),('${id(71)}','sat');
    insert into group_members values('${id(70)}','${id(1)}'),('${id(71)}','${id(1)}');
  `);
  await db.exec(fs.readFileSync('supabase/sql/study_objective_statuses.sql','utf8'));
  await actor(99,true);
  await db.exec(`update student_daily_objectives set skipped_activities=array['lesson'],practice_source='daily_quiz',practice_group_id='${id(70)}' where user_id='${id(1)}' and study_date='2026-11-07'`);
  await actor();equal(await state('lesson','2026-11-07'),'skipped');equal(await state('practice','2026-11-07'),'pending');
  await db.exec(`update student_daily_objectives set skipped_activities=array['practice'] where user_id='${id(1)}'`);
  equal(await state('practice','2026-11-07'),'pending'); // Student update matches no writable rows.
  await db.exec(`reset role;insert into daily_progress values('${id(1)}','sat','2026-11-07','${id(71)}',now(),now()),('${id(2)}','sat','2026-11-07','${id(70)}',now(),now());`);
  await actor();equal(await state('practice','2026-11-07'),'pending'); // Other group/student cannot complete it.
  await db.exec(`reset role;insert into daily_progress values('${id(1)}','sat','2026-11-07','${id(70)}',now(),null);`);
  await actor();equal(await state('practice','2026-11-07'),'in_progress');
  await db.exec(`reset role;update daily_progress set quiz_completed_at=now() where user_id='${id(1)}' and quiz_group_id='${id(70)}'`);
  await actor();equal(await state('practice','2026-11-07'),'completed');
  await denied(`update daily_progress set quiz_completed_at=now()`);
  await actor(99,true);await denied(`update student_daily_objectives set retest_exam_id='${id(13)}' where user_id='${id(1)}'`);
  await db.close();
  console.log(`${checks} verified study completion database assertions passed`);
})().catch(error => { console.error(error); process.exit(1); });
