-- ACT 2 Math is a separate course. Preserve existing authorization and test-account exclusions.
begin;
do $guard$ begin
if md5(pg_get_functiondef('public.staff_diagnosis(text)'::regprocedure))<>'47dfe21de079f094ee894785b8caa46c' then raise exception 'Concurrent function change: staff_diagnosis(text)'; end if;
if md5(pg_get_functiondef('public.staff_group_exam_evidence(uuid,uuid[])'::regprocedure))<>'01a78d023d76c6d30201fd793a770289' then raise exception 'Concurrent function change: staff_group_exam_evidence(uuid,uuid[])'; end if;
end $guard$;
CREATE OR REPLACE FUNCTION public.staff_diagnosis(p_track text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare students jsonb;
begin
 if auth.uid() is null or not coalesce(public.is_staff(),false) then raise exception 'staff_required' using errcode='42501'; end if;
 if p_track not in ('sat','est','est2','est_eng','act2') or p_track is null
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
end $function$
;
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
    where id=p_exam and track_id in ('sat','est','est2','est_eng','act2')
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
end $function$
;
commit;
