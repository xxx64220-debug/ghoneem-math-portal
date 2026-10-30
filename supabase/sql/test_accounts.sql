begin;
-- Test accounts retain normal student access and private history.
-- Report filters are evaluated at read time, including historical attempts.
alter table public.profiles add column if not exists is_test boolean not null default false;
comment on column public.profiles.is_test is 'Staff-controlled test account, excluded from student analytics and rankings.';

create or replace view public.roster with(security_invoker=true) as
 SELECT p.id AS user_id,
    p.full_name,
    p.role,
    p.status,
    (p.email)::character varying(255) AS email,
    COALESCE(string_agg(e.track_id, ', '::text ORDER BY e.track_id) FILTER (WHERE (e.status = 'active'::text)), '(none)'::text) AS tracks,
    ( SELECT count(*) AS count
           FROM attempts a
          WHERE ((a.user_id = p.id) AND (a.status = ANY (ARRAY['graded'::text, 'expired'::text])))) AS exams_taken,
    ( SELECT max(a.submitted_at) AS max
           FROM attempts a
          WHERE (a.user_id = p.id)) AS last_active,
    p.is_test
   FROM (profiles p
     LEFT JOIN enrollments e ON ((e.user_id = p.id)))
  WHERE (is_staff() AND staff_can_read_student(p.id))
  GROUP BY p.id, p.full_name, p.role, p.status, p.email;

create or replace view public.results_feed with(security_invoker=true) as
 SELECT a.id AS attempt_id,
    a.user_id,
    p.full_name,
    e.track_id,
    e.title AS exam,
    a.status,
    a.score,
    a.total,
    a.scaled_score,
    round(((100.0 * (a.score)::numeric) / (NULLIF(a.total, 0))::numeric)) AS percent,
    a.time_used,
    a.submitted_at,
    e.is_full_length,
    e.id AS exam_id
   FROM ((attempts a
     JOIN exams e ON ((e.id = a.exam_id)))
     JOIN profiles p ON ((p.id = a.user_id)))
  WHERE NOT p.is_test AND ((a.status = ANY (ARRAY['submitted'::text, 'graded'::text, 'expired'::text])) AND staff_can_touch_track(e.track_id))
  ORDER BY a.submitted_at DESC;

create or replace view public.student_by_lesson with(security_invoker=true) as
 SELECT a.user_id,
    p.full_name,
    q.track_id,
    q.topic AS lesson,
    count(*) AS questions_seen,
    count(*) FILTER (WHERE r.is_correct) AS correct,
    round(((100.0 * (count(*) FILTER (WHERE r.is_correct))::numeric) / (count(*))::numeric)) AS percent
   FROM (((attempt_results r
     JOIN attempts a ON ((a.id = r.attempt_id)))
     JOIN questions q ON ((q.id = r.question_id)))
     JOIN profiles p ON ((p.id = a.user_id)))
  WHERE NOT p.is_test AND staff_can_touch_track(q.track_id)
  GROUP BY a.user_id, p.full_name, q.track_id, q.topic
  ORDER BY p.full_name, (round(((100.0 * (count(*) FILTER (WHERE r.is_correct))::numeric) / (count(*))::numeric)));

create or replace view public.daily_quiz_mistakes with(security_invoker=true) as
 SELECT dp.track_id,
    dp.day,
    dp.user_id,
    p.full_name,
    q.id AS question_id,
    q.topic AS lesson,
    q.stem,
    (dp.answers ->> (q.id)::text) AS submitted_answer,
    k.correct AS correct_answer,
    k.explanation
   FROM ((((daily_progress dp
     JOIN profiles p ON ((p.id = dp.user_id)))
     JOIN LATERAL jsonb_object_keys(dp.answers) a(question_id) ON (true))
     JOIN questions q ON ((q.id = (a.question_id)::uuid)))
     JOIN question_keys k ON ((k.question_id = q.id)))
  WHERE NOT p.is_test AND ((dp.quiz_completed_at IS NOT NULL) AND (NOT answer_matches(q.type, (dp.answers -> (q.id)::text), k.correct)) AND staff_can_touch_track(dp.track_id));

create or replace view public.question_difficulty with(security_invoker=true) as
 WITH response_events AS (
         SELECT r.question_id,
            r.is_correct,
                CASE
                    WHEN (e.assessment_type = 'quiz'::text) THEN 'Assigned quiz'::text
                    WHEN (e.assessment_type = 'lesson_exam'::text) THEN 'Lesson exam'::text
                    WHEN ((e.assessment_type = 'full_exam'::text) OR e.is_full_length) THEN 'Full exam'::text
                    ELSE 'Assessment'::text
                END AS source
           FROM ((attempt_results r
             JOIN attempts a ON ((a.id = r.attempt_id) AND NOT EXISTS (SELECT 1 FROM public.profiles tp WHERE tp.id=a.user_id AND tp.is_test)))
             JOIN exams e ON ((e.id = a.exam_id)))
        UNION ALL
         SELECT (answer_key.question_id)::uuid AS question_id,
            answer_matches(q.type, (dp.answers -> answer_key.question_id), k.correct) AS answer_matches,
            'Daily quiz'::text AS text
           FROM (((daily_progress dp
             CROSS JOIN LATERAL jsonb_object_keys(dp.answers) answer_key(question_id))
             JOIN questions q ON ((q.id = (answer_key.question_id)::uuid)))
             JOIN question_keys k ON ((k.question_id = q.id)))
          WHERE (dp.quiz_completed_at IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.profiles tp WHERE tp.id=dp.user_id AND tp.is_test))
        ), metrics AS (
         SELECT q.track_id,
            q.topic AS lesson,
            q.id AS question_id,
            q.stem,
            string_agg(DISTINCT e.source, ' + '::text ORDER BY e.source) AS sources,
            (count(*))::integer AS answered_by,
            (count(*) FILTER (WHERE e.is_correct))::integer AS got_it_right,
            (count(*) FILTER (WHERE (NOT e.is_correct)))::integer AS got_it_wrong,
            round(((100.0 * (count(*) FILTER (WHERE e.is_correct))::numeric) / (count(*))::numeric), 1) AS percent_correct
           FROM (response_events e
             JOIN questions q ON ((q.id = e.question_id)))
          WHERE (( SELECT is_admin() AS is_admin) OR staff_can_touch_track(q.track_id))
          GROUP BY q.track_id, q.topic, q.id, q.stem
        )
 SELECT (row_number() OVER (PARTITION BY track_id ORDER BY percent_correct, answered_by DESC, question_id))::integer AS rank,
    track_id,
    lesson,
    question_id,
    stem,
    sources,
    answered_by,
    got_it_right,
    got_it_wrong,
    percent_correct
   FROM metrics
  ORDER BY track_id, ((row_number() OVER (PARTITION BY track_id ORDER BY percent_correct, answered_by DESC, question_id))::integer);

create or replace view public.hardest_current_questions with(security_invoker=true) as
 WITH events AS (
         SELECT r.question_id,
            r.is_correct,
                CASE
                    WHEN (e.assessment_type = 'quiz'::text) THEN 'Assigned quiz'::text
                    WHEN (e.assessment_type = 'lesson_exam'::text) THEN 'Lesson exam'::text
                    WHEN ((e.assessment_type = 'full_exam'::text) OR e.is_full_length) THEN 'Full exam'::text
                    ELSE 'Assessment'::text
                END AS source
           FROM ((attempt_results r
             JOIN attempts a ON ((a.id = r.attempt_id) AND NOT EXISTS (SELECT 1 FROM public.profiles tp WHERE tp.id=a.user_id AND tp.is_test)))
             JOIN exams e ON ((e.id = a.exam_id)))
          WHERE ((a.started_at < (COALESCE(NULLIF(current_setting('portal.hardest_cutoff'::text, true), ''::text), 'infinity'::text))::timestamp with time zone) AND (a.started_at >= COALESCE(( SELECT c.starts_at
                   FROM hardest_cycles c
                  WHERE ((c.track_id = e.track_id) AND (c.ends_at IS NULL))), '-infinity'::timestamp with time zone)))
        UNION ALL
         SELECT q.id,
            answer_matches(q.type, (dp.answers -> x.id), k.correct) AS answer_matches,
            'Daily quiz'::text
           FROM (((daily_progress dp
             CROSS JOIN LATERAL jsonb_object_keys(dp.answers) x(id))
             JOIN questions q ON ((q.id = (x.id)::uuid)))
             JOIN question_keys k ON ((k.question_id = q.id)))
          WHERE ((dp.quiz_completed_at IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.profiles tp WHERE tp.id=dp.user_id AND tp.is_test)) AND (dp.track_id = q.track_id) AND (dp.quiz_completed_at < (COALESCE(NULLIF(current_setting('portal.hardest_cutoff'::text, true), ''::text), 'infinity'::text))::timestamp with time zone) AND (dp.quiz_completed_at >= COALESCE(( SELECT c.starts_at
                   FROM hardest_cycles c
                  WHERE ((c.track_id = dp.track_id) AND (c.ends_at IS NULL))), '-infinity'::timestamp with time zone)))
        ), metrics AS (
         SELECT q.track_id,
            q.topic AS lesson,
            q.id AS question_id,
            q.stem,
            string_agg(DISTINCT e.source, ' + '::text ORDER BY e.source) AS sources,
            (count(*))::integer AS answered_by,
            (count(*) FILTER (WHERE e.is_correct))::integer AS got_it_right,
            (count(*) FILTER (WHERE (NOT e.is_correct)))::integer AS got_it_wrong,
            round(((100.0 * (count(*) FILTER (WHERE e.is_correct))::numeric) / (count(*))::numeric), 1) AS percent_correct
           FROM (events e
             JOIN questions q ON ((q.id = e.question_id)))
          WHERE (( SELECT is_admin() AS is_admin) OR staff_can_touch_track(q.track_id))
          GROUP BY q.track_id, q.topic, q.id, q.stem
        )
 SELECT (row_number() OVER (PARTITION BY track_id ORDER BY percent_correct, answered_by DESC, question_id))::integer AS rank,
    track_id,
    lesson,
    question_id,
    stem,
    sources,
    answered_by,
    got_it_right,
    got_it_wrong,
    percent_correct
   FROM metrics;

create or replace view public.exam_overview with(security_invoker=true) as
 SELECT track_id,
    title,
    COALESCE(array_length(question_ids, 1), 0) AS questions,
    (duration_seconds / 60) AS minutes,
    is_published,
    is_full_length,
        CASE
            WHEN is_full_length THEN 'scaled 200-800'::text
            ELSE 'raw marks'::text
        END AS score_shown,
    ( SELECT count(*) AS count
           FROM assignments a
          WHERE (a.exam_id = e.id)) AS assignments,
    ( SELECT count(*) AS count
           FROM attempts at
          WHERE (at.exam_id = e.id AND NOT EXISTS (SELECT 1 FROM public.profiles tp WHERE tp.id=at.user_id AND tp.is_test))) AS attempts_taken
   FROM exams e
  ORDER BY track_id, title;

CREATE OR REPLACE FUNCTION public.staff_diagnosis(p_track text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare students jsonb;
begin
 if auth.uid() is null or not coalesce(public.is_staff(),false) then raise exception 'staff_required' using errcode='42501'; end if;
 if p_track not in ('sat','est','est2','est_eng') or p_track is null
  or not coalesce(public.staff_can_touch_track(p_track),false) then raise exception 'track_scope_denied' using errcode='42501'; end if;
 with roster as materialized (
  select p.* from public.profiles p join public.enrollments en on en.user_id=p.id and en.track_id=p_track
  where p.role='student' and not p.is_test and public.course_history_access(p.id,p_track)
   and public.staff_can_read_student(p.id) and (public.is_admin() or exists(
    select 1 from public.groups g join public.group_members gm on gm.group_id=g.id
    where gm.user_id=p.id and g.track_id=p_track and g.instructor_id=auth.uid()))
 ), lesson_reports as materialized (
  select b.* from portal_private.diagnosis_lessons_batch(
   (select coalesce(array_agg(id),'{}'::uuid[]) from roster),p_track) b
 )
 select coalesce(jsonb_agg(jsonb_build_object('user_id',p.id,'full_name',p.full_name,'role','student','tracks',p_track,
  'practice_open',public.is_enrolled(p.id,p_track),
  'lessons',coalesce(l.lessons,'[]'::jsonb),
  'daily_groups',portal_private.diagnosis_daily(p.id,p_track,auth.uid()),
  'latest',a.row,
  'repeat_questions',(select count(*) from public.practice_notebook n join public.questions q on q.id=n.question_id
    join public.question_keys k on k.question_id=q.id where n.user_id=p.id and n.tries>=2 and n.correct_streak<2
      and portal_private.question_eligible(q,k,p_track,false))
 ) order by p.full_name,p.id),'[]'::jsonb) into students
 from roster p left join lesson_reports l on l.user_id=p.id
 left join lateral (
  select jsonb_build_object('id',a.id,'title',e.title,'assessment_type',e.assessment_type,'attempt_no',a.attempt_no,
   'score',a.score,'total',a.total,'percent',round(100.0*a.score/nullif(a.total,0)),'time_used',a.time_used,
   'submitted_at',a.submitted_at,'answered_count',(select count(*) from public.attempt_answers aa where aa.attempt_id=a.id
    and aa.response is not null and aa.response not in ('null'::jsonb,'""'::jsonb))) as row
  from public.attempts a join public.exams e on e.id=a.exam_id
  where a.user_id=p.id and e.track_id=p_track and a.status in ('submitted','graded','expired')
  order by a.submitted_at desc nulls last,a.attempt_no desc,a.id desc limit 1
 ) a on true;
 return jsonb_build_object('track_id',p_track,'students',students);
end $function$;

CREATE OR REPLACE FUNCTION public.staff_group_exam_evidence(p_exam uuid, p_students uuid[])
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare assessment public.exams%rowtype; students jsonb;
begin
  if auth.uid() is null or not coalesce(public.is_staff(),false) then
    raise exception 'staff_required' using errcode='42501';
  end if;
  select * into assessment from public.exams
    where id=p_exam and track_id in ('sat','est','est2','est_eng')
      and public.staff_can_touch_track(track_id) and assessment_type in ('full_exam','lesson_exam');
  if not found then raise exception 'exam_not_available' using errcode='42501'; end if;
  if p_students is null or cardinality(p_students)>100 then
    raise exception 'invalid_student_selection' using errcode='22023';
  end if;
  -- Reject the whole request, including nonexistent IDs, without leaking which
  -- student was outside the caller's existing track / group permissions.
  if exists(select 1 from unnest(p_students) u(id) where id is null
    or not coalesce(public.staff_can_read_student(id),false)
    or not public.is_enrolled(id,assessment.track_id)
    or not exists(select 1 from public.profiles p where p.id=u.id and p.role='student')
    or (not public.is_admin() and not exists(
      select 1 from public.group_members gm join public.groups g on g.id=gm.group_id
      where gm.user_id=u.id and g.track_id=assessment.track_id and g.instructor_id=auth.uid()))) then
    raise exception 'student_scope_denied' using errcode='42501';
  end if;

  with chosen as (select distinct u.id from unnest(p_students) u(id) join public.profiles p on p.id=u.id where not p.is_test),
  attempts as (
    select c.id as user_id, a.id, a.attempt_no, a.submitted_at,
      case when a.id is null then
        case when exists(select 1 from public.attempts pending where pending.user_id=c.id
          and pending.exam_id=p_exam and pending.status in ('submitted','graded','expired'))
          then 'ungraded' else 'missing' end
        when a.score is null then 'ungraded'
        when not exists(select 1 from public.attempt_answers aa where aa.attempt_id=a.id
          and aa.response is not null and aa.response not in ('null'::jsonb,'""'::jsonb)) then 'no_responses'
        when assessment.review_policy<>'full_review' or a.review_unlocks_at is null
          or a.review_unlocks_at>now() then 'locked' else 'available' end as state
    from chosen c left join lateral (
      select a.* from public.attempts a where a.user_id=c.id and a.exam_id=p_exam
        and a.status in ('submitted','graded','expired')
      order by a.submitted_at desc nulls last, a.attempt_no desc, a.id desc limit 1
    ) a on true
  ), lesson_counts as (
    -- DISTINCT exam IDs mirrors the student plan's seen-ID guard. Only stored
    -- boolean results count; no regrading, answer matching or timing inference.
    select a.user_id, coalesce(nullif(btrim(q.assets->>'curriculum_lesson'),''),
        nullif(btrim(q.topic),''),'Unclassified questions') as lesson,
      count(*)::int as seen, count(*) filter(where r.is_correct)::int as correct,
      count(*) filter(where not r.is_correct)::int as missed,
      count(*) filter(where not r.is_correct and
        (aa.response is null or aa.response='null'::jsonb or aa.response='""'::jsonb))::int as blank
    from attempts a
    join (select distinct unnest(assessment.question_ids) as id) ids on a.state='available'
    join public.questions q on q.id=ids.id and q.track_id=assessment.track_id
    join public.question_keys k on k.question_id=q.id
    join public.attempt_results r on r.attempt_id=a.id and r.question_id=q.id
    left join public.attempt_answers aa on aa.attempt_id=a.id and aa.question_id=q.id
    where r.is_correct is not null and portal_private.question_eligible(q,k,assessment.track_id,false)
    group by a.user_id, coalesce(nullif(btrim(q.assets->>'curriculum_lesson'),''),
        nullif(btrim(q.topic),''),'Unclassified questions')
  ), lessons as (
    select user_id, jsonb_agg(jsonb_build_object('lesson',lesson,
      'classified',lesson not in ('Unclassified questions','Mixed / untagged'),
      'seen',seen,'correct',correct,'missed',missed,'blank',blank,
      'percent',round(100.0*correct/seen)) order by missed desc,
        round(100.0*correct/seen), lesson collate "C") as rows
    from lesson_counts group by user_id
  )
  select coalesce(jsonb_agg(jsonb_build_object('user_id',a.user_id,'state',a.state,
    'attempt',case when a.id is not null then jsonb_build_object('id',a.id,
      'attempt_no',a.attempt_no,'submitted_at',a.submitted_at) else null end,
    'lessons',coalesce(l.rows,'[]'::jsonb)) order by a.user_id),'[]'::jsonb)
  into students from attempts a left join lessons l on l.user_id=a.user_id;
  return jsonb_build_object('exam_id',p_exam,'track_id',assessment.track_id,'students',students);
end $function$;

CREATE OR REPLACE FUNCTION public.daily_group_state(p_user uuid, p_track text, p_group uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  d date := (now() at time zone 'Africa/Cairo')::date;
  qids uuid[]; gid uuid; existing_progress boolean;
  progress_ public.daily_progress%rowtype;
  quiz_ jsonb;
  leaders_ jsonb;
  myrank_ integer;
  mytotal_ integer;
  current_ integer;
  best_ integer;
  week_ jsonb;
begin
  if not exists (
    select 1 from public.profiles p join public.enrollments e on e.user_id=p.id
    join public.tracks t on t.id=e.track_id
    where p.id=p_user and p.role='student' and p.status='active'
      and e.track_id=p_track and public.is_enrolled(p_user,p_track)
  ) then raise exception 'not_enrolled_in_track'; end if;

  gid:=public.daily_quiz_group(p_user,p_track,p_group);
  perform pg_advisory_xact_lock(hashtextextended('daily-user:'||p_user::text||':'||p_track||':'||coalesce(gid::text,'course')||':'||d::text,0));
  perform pg_advisory_xact_lock(hashtextextended('daily:'||coalesce(gid::text,p_track)||':'||d::text,0));
  if gid is null then select question_ids into qids from public.daily_quizzes where track_id=p_track and day=d;
  else select question_ids into qids from public.daily_group_quizzes where group_id=gid and day=d;end if;
  if qids is null then
  select array(
    select q.id from public.questions q join public.question_keys k on k.question_id=q.id
    where q.track_id=p_track and q.type='mcq' and portal_private.question_eligible(q,k,p_track,true) and not exists(select 1 from public.question_catalogue c where c.question_id=q.id and c.reserve)
      and ((gid is not null and exists(select 1 from public.groups g where g.id=gid and cardinality(g.daily_lessons)>0 and q.topic=any(g.daily_lessons)))
       or ((gid is null or exists(select 1 from public.groups g where g.id=gid and cardinality(g.daily_lessons)=0))
       and exists(select 1 from public.portal_track_controls c where c.track_id=p_track and
       (c.daily_mode='random' or (c.daily_mode='lessons' and q.topic=any(c.daily_lessons)) or (c.daily_mode='selected' and q.id=any(c.daily_question_ids))))))
    order by md5(d::text || coalesce(gid::text,'') || q.id::text) limit 5
  ) into qids;
  if coalesce(array_length(qids,1),0)<>5 then raise exception 'daily_questions_unavailable'; end if;
  if gid is null then insert into public.daily_quizzes(track_id,day,question_ids) values(p_track,d,qids);
  else insert into public.daily_group_quizzes(group_id,day,question_ids) values(gid,d,qids);end if;
  end if;
  if coalesce(array_length(qids,1),0)<>5 then raise exception 'daily_questions_unavailable'; end if;

  insert into public.daily_progress(user_id,track_id,day,quiz_group_id) values(p_user,p_track,d,gid)
  on conflict (user_id,track_id,day,group_scope) do nothing;
  select * into progress_ from public.daily_progress
  where user_id=p_user and track_id=p_track and day=d and quiz_group_id is not distinct from gid;

  if progress_.quiz_completed_at is null and (select count(*) from public.questions q join public.question_keys k on k.question_id=q.id where q.id=any(qids) and portal_private.question_eligible(q,k,p_track,true))<>5 then raise exception 'daily_content_under_review'; end if;

  select jsonb_agg(jsonb_build_object(
    'id',q.id,'stem',q.stem,'choices',q.choices,'topic',q.topic,'assets',q.assets,
    'answer',case when progress_.quiz_completed_at is null then null else
      jsonb_build_object('correct',k.correct,'explanation',k.explanation,
        'submitted',progress_.answers->q.id::text) end
  ) order by ord.n) into quiz_
  from unnest(qids) with ordinality ord(id,n)
  join public.questions q on q.id=ord.id join public.question_keys k on k.question_id=q.id;

  with ranked as (
    select e.user_id, p.full_name,
      coalesce(sum(dp.points),0)::integer as points,
      count(dp.quiz_completed_at)::integer as completed,
      row_number() over (order by coalesce(sum(dp.points),0) desc,
        count(dp.quiz_completed_at) desc, e.user_id) as rank
    from public.enrollments e join public.profiles p on p.id=e.user_id
    left join public.daily_progress dp on dp.user_id=e.user_id and dp.track_id=e.track_id and dp.quiz_group_id is not distinct from gid
    where not p.is_test and e.track_id=p_track and public.is_enrolled(e.user_id,p_track) and (gid is null or exists(select 1 from public.group_members gm where gm.group_id=gid and gm.user_id=e.user_id))
    group by e.user_id,p.full_name
  ) select coalesce(jsonb_agg(jsonb_build_object(
      'rank',rank,'name',split_part(coalesce(full_name,'Student'),' ',1)
        || case when position(' ' in btrim(coalesce(full_name,'')))>0 then ' '
          || left(reverse(split_part(reverse(btrim(full_name)),' ',1)),1) || '.' else '' end,
      'points',points,'completed',completed
    ) order by rank) filter (where rank<=10),'[]'::jsonb),
    (max(rank) filter (where user_id=p_user))::integer,
    max(points) filter (where user_id=p_user)
    into leaders_,myrank_,mytotal_ from ranked;
  -- Test accounts keep their own points without joining the real ranking.
  select coalesce(sum(dp.points),0)::int into mytotal_ from public.daily_progress dp
   where dp.user_id=p_user and dp.track_id=p_track and dp.quiz_group_id is not distinct from gid;

  with days as (
    select day, day - (row_number() over(order by day))::int as island
    from public.daily_progress where user_id=p_user and track_id=p_track and quiz_group_id is not distinct from gid
      and quiz_completed_at is not null and day<=d
  ), runs as (
    select count(*)::int as length,max(day) as last_day from days group by island
  ) select coalesce(max(length) filter(where last_day>=d-1),0),
      coalesce(max(length),0) into current_,best_ from runs;
  if progress_.quiz_completed_at is null and (select count(*) from public.questions q join public.question_keys k on k.question_id=q.id where q.id=any(qids) and portal_private.question_eligible(q,k,p_track,true))<>5 then raise exception 'daily_content_under_review'; end if;

  select jsonb_agg(jsonb_build_object('date',d-offset_,
    'completed',exists(select 1 from public.daily_progress p where p.user_id=p_user
      and p.track_id=p_track and p.quiz_group_id is not distinct from gid and p.day=d-offset_ and p.quiz_completed_at is not null),
    'today',offset_=0) order by offset_ desc) into week_ from generate_series(0,6) offset_;

  return jsonb_build_object('date',d,'reset_at',((d+1)::timestamp at time zone 'Africa/Cairo'),
    'server_now',now(),'streak',jsonb_build_object('current',current_,'longest',best_,'week',week_),
    'group_id',gid,'scope_id',coalesce(gid,'00000000-0000-0000-0000-000000000000'::uuid),'group_name',coalesce((select name from public.groups where id=gid),'Earlier course quiz'),
    'groups',(select coalesce(jsonb_agg(x order by x->>'name',x->>'id'),'[]'::jsonb) from (
     select jsonb_build_object('id',g.id,'name',g.name) x from public.groups g join public.group_members gm on gm.group_id=g.id where gm.user_id=p_user and g.track_id=p_track and (g.course_starts_on is null or g.course_starts_on<=d) and (g.course_ends_on is null or g.course_ends_on>=d)
     union all select jsonb_build_object('id','00000000-0000-0000-0000-000000000000','name','Earlier course quiz') where exists(select 1 from public.daily_progress dp where dp.user_id=p_user and dp.track_id=p_track and dp.quiz_group_id is null)
    ) options),'selection_mode',case when gid is not null and exists(select 1 from public.groups where id=gid and cardinality(daily_lessons)>0) then 'group lessons' else (select daily_mode from public.portal_track_controls where track_id=p_track) end,'track',p_track,'quiz',quiz_,'score',progress_.quiz_score,
    'completed',progress_.quiz_completed_at is not null,
    'checklist',jsonb_build_object('quiz',progress_.quiz_completed_at is not null,
      'focus',progress_.focus_done,'review',progress_.review_done,
      'bonus',progress_.bonus_awarded),
    'points_today',progress_.points,'points_total',coalesce(mytotal_,0),
    'rank',myrank_,'leaderboard',leaders_);
end;
$function$;

CREATE OR REPLACE FUNCTION portal_private.staff_bank_operations(p_track text, p_group uuid DEFAULT NULL::uuid, p_cycle uuid DEFAULT NULL::uuid, p_filter text DEFAULT 'all'::text, p_page integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare role_ text; start_ timestamptz:='-infinity';end_ timestamptz:='infinity';result_ jsonb;
begin
 role_:=portal_private.require_course_staff(p_track,p_group);
 if p_filter is null or p_filter not in ('all','unused','underused','hardest','held','pending','reserve') or p_page is null or p_page not between 0 and 100000 then raise exception 'invalid_filter';end if;
 if p_cycle is not null then
 select starts_at,coalesce(ends_at,'infinity') into start_,end_ from public.hardest_cycles where id=p_cycle and track_id=p_track;
 if not found then raise exception 'cycle_track_mismatch';end if;end if;
 with learners as materialized(
 select p.id from public.profiles p where p.role='student' and not p.is_test
 and (exists(select 1 from public.enrollments en where en.user_id=p.id and en.track_id=p_track)
 or exists(select 1 from public.attempts a join public.exams e on e.id=a.exam_id where a.user_id=p.id and e.track_id=p_track)
 or exists(select 1 from public.daily_progress d where d.user_id=p.id and d.track_id=p_track))
 and (role_='admin' or exists(select 1 from public.group_members gm join public.groups g on g.id=gm.group_id
 where gm.user_id=p.id and g.track_id=p_track and g.instructor_id=auth.uid()))
 and (p_group is null or exists(select 1 from public.group_members gm where gm.user_id=p.id and gm.group_id=p_group))
 ),events as materialized(
 select r.question_id,a.user_id,r.is_correct,a.started_at at_,a.id::text||':'||r.question_id::text event_
 from public.attempt_results r join public.attempts a on a.id=r.attempt_id join public.exams e on e.id=a.exam_id
 join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id
 where e.track_id=p_track and q.track_id=p_track and a.user_id in(select id from learners)
 and a.status in ('submitted','graded','expired') and a.score is not null and r.is_correct is not null
 and coalesce(k.correct->>'void','false')<>'true' and a.started_at>=start_ and a.started_at<end_
 union all
 select q.id,d.user_id,public.answer_matches(q.type,d.answers->q.id::text,k.correct),d.quiz_completed_at,
 d.user_id::text||':'||d.track_id||':'||d.day::text||':'||q.id::text
 from public.daily_progress d cross join lateral jsonb_object_keys(d.answers) x(id)
 join public.questions q on q.id::text=x.id join public.question_keys k on k.question_id=q.id
 where d.track_id=p_track and q.track_id=p_track and d.user_id in(select id from learners)
 and d.quiz_completed_at is not null and d.quiz_score is not null and coalesce(k.correct->>'void','false')<>'true'
 and d.answers->x.id is not null and jsonb_typeof(d.answers->x.id)<>'null'
 and d.quiz_completed_at>=start_ and d.quiz_completed_at<end_
 ),per_student as materialized(
 select question_id,user_id,count(*) responses,(array_agg(is_correct order by at_,event_))[1] first_correct,
 (array_agg(is_correct order by at_ desc,event_ desc))[1] latest_correct,max(at_) last_used
 from events group by question_id,user_id
 ),metrics as materialized(
 select question_id,count(*)::int unique_students,sum(responses)::int responses,
 count(*) filter(where first_correct)::int first_correct,count(*) filter(where latest_correct)::int latest_correct,
 count(*) filter(where not first_correct and responses>1)::int repeat_candidates,
 count(*) filter(where not first_correct and responses>1 and latest_correct)::int improved,max(last_used) last_used
 from per_student group by question_id
 ),exposure as materialized(
 select qid,count(distinct e.id)::int published_exams,count(distinct a.id)::int assignments
 from public.exams e cross join lateral unnest(e.question_ids) qid left join public.assignments a on a.exam_id=e.id
 and (p_group is null or a.group_id=p_group or a.user_id in(select id from learners))
 and (role_='admin' or a.user_id in(select id from learners) or exists(select 1 from public.groups ag where ag.id=a.group_id and ag.track_id=p_track and ag.instructor_id=auth.uid()))
 where e.track_id=p_track and e.is_published and (role_='admin' or exists(select 1 from public.assignments a2 where a2.exam_id=e.id
 and (a2.user_id in(select id from learners) or exists(select 1 from public.groups g where g.id=a2.group_id and g.instructor_id=auth.uid() and g.track_id=p_track))))
 group by qid
 ),bank as materialized(
 select q.id,q.topic lesson,left(q.stem,160) stem,q.difficulty,md5(coalesce(to_jsonb(c)::text,'{}')) assets_hash,
 coalesce(q.assets->>'source_code',q.id::text) code,
 portal_private.question_eligible(q,k,p_track,false) ready,coalesce(q.assets->>'release_hold_reason','') hold_reason,
 coalesce(q.assets->>'answer_review_status','') math_review,
 coalesce(c.reserve,false) reserve,
 coalesce(m.unique_students,0) unique_students,coalesce(m.responses,0) responses,
 round(100.0*m.first_correct/nullif(m.unique_students,0),1) first_success,
 round(100.0*m.latest_correct/nullif(m.unique_students,0),1) latest_success,
 coalesce(m.repeat_candidates,0) repeat_candidates,coalesce(m.improved,0) improved,
 round(100.0*m.improved/nullif(m.repeat_candidates,0),1) repeat_improvement,m.last_used,
 coalesce(x.published_exams,0) published_exams,coalesce(x.assignments,0) assignments
 from public.questions q left join public.question_catalogue c on c.question_id=q.id left join public.question_keys k on k.question_id=q.id left join metrics m on m.question_id=q.id
 left join exposure x on x.qid=q.id where q.track_id=p_track and coalesce(q.assets->>'bank_removed','false')<>'true'
 ),filtered as(select * from bank where p_filter='all' or (p_filter='unused' and ready and not reserve and assignments=0 and responses=0)
 or (p_filter='underused' and ready and assignments>0 and unique_students<3) or (p_filter='hardest' and unique_students>0)
 or (p_filter='held' and not ready) or (p_filter='pending' and math_review<>'independently_solved') or (p_filter='reserve' and reserve)),
 page_ as(select * from filtered order by case when p_filter='hardest' then first_success end asc nulls last,
 case when p_filter='hardest' then unique_students end desc,lesson,id limit 50 offset p_page*50)
 select jsonb_build_object('track',p_track,'group',p_group,'cycle',p_cycle,'total',(select count(*) from filtered),'page',p_page,
 'items',coalesce((select jsonb_agg(to_jsonb(p) order by case when p_filter='hardest' then first_success end asc nulls last,
 case when p_filter='hardest' then unique_students end desc,lesson,id) from page_ p),'[]'::jsonb),
 'summary',jsonb_build_object('total',(select count(*) from bank),'unused',(select count(*) from bank where ready and not reserve and assignments=0 and responses=0),
 'held',(select count(*) from bank where not ready),'reserve',(select count(*) from bank where reserve),'students',(select count(*) from learners))) into result_;
 return result_;
end $function$;

CREATE OR REPLACE FUNCTION public.portal_manage(p_actor uuid, p_action text, p_data jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare group_ uuid; scope_ uuid; groups_ jsonb; role_ text; track_ text:=p_data->>'track'; id_ uuid; ids_ uuid[]; c public.portal_track_controls%rowtype; data_ jsonb; n int; student_ uuid; mode_ text; day_ date; before_ jsonb; report_ public.portal_reports%rowtype;
begin
 select role into role_ from public.profiles where id=p_actor and status='active';
 if role_ is null or role_ not in ('admin','instructor') then raise exception 'staff_required';end if;
 if track_ is null or not exists(select 1 from public.tracks where id=track_ and is_active) then raise exception 'choose_track';end if;
 if role_='instructor' and not exists(select 1 from public.instructor_tracks where user_id=p_actor and track_id=track_) then raise exception 'forbidden_track';end if;
 select * into c from public.portal_track_controls where track_id=track_;
 if p_action in ('quiz.list','quiz.reset') then
  select coalesce(jsonb_agg(jsonb_build_object('id',g.id,'name',g.name) order by lower(g.name),g.id),'[]'::jsonb) into groups_
   from public.groups g where g.track_id=track_ and (role_='admin' or g.instructor_id=p_actor);
  if p_action='quiz.reset' and not p_data ? 'group_id' then raise exception 'quiz_group_required'; end if;
  if p_data ? 'group_id' then scope_:=(p_data->>'group_id')::uuid;
  else scope_:=coalesce((groups_->0->>'id')::uuid,'00000000-0000-0000-0000-000000000000'::uuid); end if;
  if scope_ is null then raise exception 'quiz_group_required'; end if;
  group_:=nullif(scope_,'00000000-0000-0000-0000-000000000000'::uuid);
  if group_ is not null and not exists(select 1 from public.groups g where g.id=group_ and g.track_id=track_ and (role_='admin' or g.instructor_id=p_actor)) then raise exception 'group_scope_denied'; end if;
 end if;
 if p_action='revision.list' then
  select coalesce(jsonb_agg(jsonb_build_object('id',r.question_id,'lesson',r.lesson,'idea',r.idea,'difficulty',r.difficulty,'active',r.active,'source',coalesce(q.assets->>'source_code',q.assets->>'code',''),'stem',q.stem,'ready',r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation) and nullif(q.assets->>'release_hold_reason','') is null) order by r.lesson,r.idea,r.question_id),'[]') into data_
  from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id where q.track_id=track_;
  return jsonb_build_object('visible',c.revision_visible,'items',data_);
 elsif p_action='quiz.list' then
  return jsonb_build_object('group_id',scope_,'groups',groups_,'group_name',coalesce((select name from public.groups where id=group_),'Earlier course quiz'),'settings',to_jsonb(c),'today_frozen',exists(select 1 from public.daily_progress where track_id=track_ and day=(now() at time zone 'Africa/Cairo')::date),
   'today',(select jsonb_build_object('day',day,'question_ids',question_ids) from public.daily_quizzes where track_id=track_ and day=(now() at time zone 'Africa/Cairo')::date),
   'questions',(select coalesce(jsonb_agg(jsonb_build_object('id',q.id,'lesson',q.topic,'stem',q.stem,'source',coalesce(q.assets->>'source_code',q.assets->>'code','')) order by q.topic,q.id),'[]') from public.questions q join public.question_keys k on k.question_id=q.id where q.track_id=track_ and q.type='mcq' and nullif(q.assets->>'verified_release','') is not null and nullif(q.assets->>'release_hold_reason','') is null and length(btrim(k.explanation))>0 and jsonb_array_length(q.choices)>=4 and jsonb_typeof(k.correct)='string' and exists(select 1 from jsonb_array_elements(q.choices) ch where ch->>'key'=k.correct#>>'{}')),
   'students',(select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'name',p.full_name,'completed',coalesce(d.completed,0),'points',coalesce(d.points,0),'score_today',d.score_today,'average_score',d.average_score) order by p.full_name),'[]') from public.profiles p join public.enrollments e on e.user_id=p.id and e.track_id=track_ left join lateral(select count(quiz_completed_at) completed,sum(points) points,max(quiz_score) filter(where day=(now() at time zone 'Africa/Cairo')::date) score_today,round(avg(quiz_score),2) average_score from public.daily_progress dp where dp.user_id=p.id and dp.track_id=track_ and dp.quiz_group_id is not distinct from group_) d on true where p.role='student' and not p.is_test and (group_ is null or exists(select 1 from public.group_members gm where gm.group_id=group_ and gm.user_id=p.id) or exists(select 1 from public.daily_progress dp where dp.user_id=p.id and dp.track_id=track_ and dp.quiz_group_id=group_)) and (role_='admin' or exists(select 1 from public.groups g join public.group_members gm on gm.group_id=g.id where gm.user_id=p.id and g.instructor_id=p_actor and g.track_id=track_))));
 elsif p_action='reports.list' then
  select coalesce(jsonb_agg(x order by x->>'created_at' desc),'[]') into data_ from (
   select to_jsonb(r)||jsonb_build_object('student',p.full_name,'question_stem',q.stem,'source',q.assets->>'source_code') x from public.portal_reports r join public.profiles p on p.id=r.user_id left join public.questions q on q.id=r.question_id
   where r.track_id=track_ and (role_='admin' or r.user_id=p_actor or exists(select 1 from public.groups g join public.group_members gm on gm.group_id=g.id where gm.user_id=r.user_id and g.instructor_id=p_actor and g.track_id=track_)) and (coalesce(p_data->>'status','all')='all' or r.status=p_data->>'status') order by r.created_at desc limit 200) z;
  return jsonb_build_object('items',data_,'open_count',(select count(*) from public.portal_reports r where r.track_id=track_ and (role_='admin' or r.user_id=p_actor or exists(select 1 from public.groups g join public.group_members gm on gm.group_id=g.id where gm.user_id=r.user_id and g.instructor_id=p_actor and g.track_id=track_)) and r.status in ('open','in_review')));
 elsif p_action='revision.visibility' then
  if jsonb_typeof(p_data->'visible') is distinct from 'boolean' then raise exception 'invalid_visibility';end if;
  update public.portal_track_controls set revision_visible=(p_data->>'visible')::boolean,updated_at=now() where track_id=track_;
  data_:=jsonb_build_object('visible',(p_data->>'visible')::boolean);
 elsif p_action='revision.release' then
  if jsonb_typeof(p_data->'active') is distinct from 'boolean' then raise exception 'invalid_release';end if;
  select array_agg(x::uuid) into ids_ from jsonb_array_elements_text(p_data->'ids') x;
  if coalesce(cardinality(ids_),0) not between 1 and 1000 or (select count(distinct x) from unnest(ids_) x)<>cardinality(ids_) then raise exception 'select_questions';end if;
  if (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where r.question_id=any(ids_) and q.track_id=track_)<>cardinality(ids_) then raise exception 'question_track_mismatch';end if;
  if (p_data->>'active')::boolean and exists(select 1 from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id where r.question_id=any(ids_) and (r.fingerprint<>public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation) or nullif(q.assets->>'release_hold_reason','') is not null)) then raise exception 'questions_need_review';end if;
  update public.revision_items set active=(p_data->>'active')::boolean where question_id=any(ids_);
  data_:=jsonb_build_object('count',cardinality(ids_),'active',(p_data->>'active')::boolean);
 elsif p_action='quiz.save' then
  mode_:=p_data->>'mode';if mode_ is null or mode_ not in ('random','lessons','selected') then raise exception 'invalid_quiz_mode';end if;
  select coalesce(array_agg(x::uuid),'{}') into ids_ from jsonb_array_elements_text(coalesce(p_data->'ids','[]')) x;
  if cardinality(ids_)>1000 or (select count(distinct x) from unnest(ids_) x)<>cardinality(ids_) then raise exception 'invalid_question_selection';end if;
  if mode_='selected' and cardinality(ids_)<5 then raise exception 'select_at_least_five_questions';end if;
  select count(*) into n from public.questions q join public.question_keys k on k.question_id=q.id where q.track_id=track_ and q.type='mcq' and nullif(q.assets->>'verified_release','') is not null and nullif(q.assets->>'release_hold_reason','') is null and length(btrim(k.explanation))>0 and jsonb_array_length(q.choices)>=4 and jsonb_typeof(k.correct)='string' and exists(select 1 from jsonb_array_elements(q.choices) ch where ch->>'key'=k.correct#>>'{}') and (mode_='random' or (mode_='selected' and q.id=any(ids_)) or (mode_='lessons' and coalesce(p_data->'lessons','[]') ? q.topic));
  if n<5 then raise exception 'quiz_pool_needs_five_valid_questions';end if;
  if mode_='selected' and n<>cardinality(ids_) then raise exception 'selected_question_unavailable';end if;
  -- Same lock as daily_state: selecting today's questions cannot race an edit.
  perform pg_advisory_xact_lock(hashtextextended('daily:'||track_||':'||(now() at time zone 'Africa/Cairo')::date::text,0));
  update public.portal_track_controls set daily_mode=mode_,daily_question_ids=case when mode_='selected' then ids_ else '{}'::uuid[] end,daily_lessons=case when mode_='lessons' then array(select jsonb_array_elements_text(p_data->'lessons')) else '{}'::text[] end,updated_at=now() where track_id=track_;
  if not exists(select 1 from public.daily_progress where track_id=track_ and day=(now() at time zone 'Africa/Cairo')::date) then delete from public.daily_quizzes where track_id=track_ and day=(now() at time zone 'Africa/Cairo')::date;end if;
  data_:=jsonb_build_object('mode',mode_,'eligible',n,'today_frozen',exists(select 1 from public.daily_progress where track_id=track_ and day=(now() at time zone 'Africa/Cairo')::date));
 elsif p_action='quiz.reset' then
  if role_<>'admin' then raise exception 'admin_required';end if;
  if p_data->>'confirm' is distinct from 'RESET' then raise exception 'reset_confirmation_required';end if;
  student_:=(p_data->>'user_id')::uuid; mode_:=p_data->>'mode';day_:=nullif(p_data->>'day','')::date;
  if mode_ is null or mode_ not in ('quiz','all') then raise exception 'invalid_reset_mode';end if;
  if not exists(select 1 from public.enrollments e join public.profiles p on p.id=e.user_id where e.user_id=student_ and e.track_id=track_ and p.role='student') then raise exception 'student_not_enrolled';end if;
  if day_ is null and p_data->>'range' is distinct from 'all' then raise exception 'reset_date_required';end if;
  perform pg_advisory_xact_lock(hashtextextended('daily:'||coalesce(group_::text,track_)||':'||(now() at time zone 'Africa/Cairo')::date::text,0));
  perform 1 from public.daily_progress where user_id=student_ and track_id=track_ and quiz_group_id is not distinct from group_ and (day_ is null or day=day_) for update;
  select coalesce(jsonb_agg(to_jsonb(dp)),'[]') into before_ from public.daily_progress dp where user_id=student_ and track_id=track_ and quiz_group_id is not distinct from group_ and (day_ is null or day=day_);
  insert into public.daily_reset_archive(actor_id,user_id,track_id,reset_mode,previous_progress) values(p_actor,student_,track_,mode_,before_) returning id into id_;
  if mode_='all' then delete from public.daily_progress where user_id=student_ and track_id=track_ and quiz_group_id is not distinct from group_ and (day_ is null or day=day_);
  else update public.daily_progress set quiz_completed_at=null,quiz_score=null,answers='{}',points=0,bonus_awarded=false where user_id=student_ and track_id=track_ and quiz_group_id is not distinct from group_ and (day_ is null or day=day_);end if;
  get diagnostics n=row_count;
  data_:=jsonb_build_object('count',n,'archive_id',id_);
 elsif p_action='reports.update' then
  id_:=(p_data->>'id')::uuid;
  if p_data->>'status' is null or p_data->>'status' not in ('open','in_review','resolved','dismissed') or length(coalesce(p_data->>'note',''))>2000 then raise exception 'invalid_report_status';end if;
  update public.portal_reports r set status=p_data->>'status',staff_note=coalesce(p_data->>'note',''),updated_at=now() where r.id=id_ and r.track_id=track_ and (role_='admin' or r.user_id=p_actor or exists(select 1 from public.groups g join public.group_members gm on gm.group_id=g.id where gm.user_id=r.user_id and g.instructor_id=p_actor and g.track_id=track_));
  if not found then raise exception 'report_not_found';end if;
  data_:=jsonb_build_object('id',id_,'status',p_data->>'status');
 else raise exception 'invalid_action';end if;
 insert into public.audit_log(actor_id,action,target_type,target_id,meta) values(p_actor,p_action,split_part(p_action,'.',1),coalesce(id_::text,track_),jsonb_build_object('track',track_,'result',data_));
 return data_;
end $function$;

CREATE OR REPLACE FUNCTION portal_private.admin_course_enrollments(p_track text DEFAULT ''::text, p_filter text DEFAULT 'all'::text, p_search text DEFAULT ''::text, p_page integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare result_ jsonb;
begin
 if not coalesce(public.is_admin(),false) then raise exception 'admin_required';end if;
 if p_filter is null or p_filter not in ('all','active','expiring','expired','future','paused','pending','unrecorded') or p_page is null or p_page not between 0 and 100000 or length(coalesce(p_search,''))>200 then raise exception 'invalid_filter';end if;
 with base as materialized(
 select e.*,p.full_name,p.email,p.status account_status,
 case when e.status='paused' then 'paused' when e.starts_at>now() then 'future' when e.ends_at<=now() then 'expired'
 when e.ends_at<=now()+interval '7 days' then 'expiring' else 'active' end access_state
 from public.enrollments e join public.profiles p on p.id=e.user_id where p.role='student' and not p.is_test
 and (coalesce(p_track,'')='' or e.track_id=p_track)
 and (coalesce(p_search,'')='' or strpos(lower(concat_ws(' ',p.full_name,p.email,e.course_label)),lower(p_search))>0)
 ), filtered as(select * from base where p_filter='all' or access_state=p_filter or (p_filter in ('pending','unrecorded') and payment_status=p_filter)),
 page_ as(select * from filtered order by ends_at nulls last,full_name,user_id,track_id limit 50 offset p_page*50)
 select jsonb_build_object('total',(select count(*) from filtered),'page',p_page,'items',coalesce((select jsonb_agg(to_jsonb(x) order by ends_at nulls last,full_name,user_id,track_id) from page_ x),'[]'::jsonb),
 'summary',jsonb_build_object('active',(select count(*) from base where access_state='active'),'expiring',(select count(*) from base where access_state='expiring'),'expired',(select count(*) from base where access_state='expired'),'unrecorded',(select count(*) from base where payment_status='unrecorded'))) into result_;
 return result_;
end $function$;
commit;
