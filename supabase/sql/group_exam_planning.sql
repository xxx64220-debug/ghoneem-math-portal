-- Read-only EST I lesson aggregates. Apply after portal_access, portal_scope,
-- portal_upgrade and pending_exam_grading. No answer keys leave this function.
begin;
create or replace function public.staff_group_exam_evidence(p_exam uuid, p_students uuid[])
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare assessment public.exams%rowtype; students jsonb;
begin
  if auth.uid() is null or not coalesce(public.is_staff(),false)
     or not coalesce(public.staff_can_touch_track('est'),false) then
    raise exception 'staff_required' using errcode='42501';
  end if;
  select * into assessment from public.exams
    where id=p_exam and track_id='est' and assessment_type in ('full_exam','lesson_exam');
  if not found then raise exception 'exam_not_available' using errcode='42501'; end if;
  if p_students is null or cardinality(p_students)>100 then
    raise exception 'invalid_student_selection' using errcode='22023';
  end if;
  -- Reject the whole request, including nonexistent IDs, without leaking which
  -- student was outside the caller's existing track / group permissions.
  if exists(select 1 from unnest(p_students) u(id) where id is null
    or not coalesce(public.staff_can_read_student(id),false)
    or not public.is_enrolled(id,'est')
    or not exists(select 1 from public.profiles p where p.id=u.id and p.role='student')
    or (not public.is_admin() and not exists(
      select 1 from public.group_members gm join public.groups g on g.id=gm.group_id
      where gm.user_id=u.id and g.track_id='est' and g.instructor_id=auth.uid()))) then
    raise exception 'student_scope_denied' using errcode='42501';
  end if;

  with chosen as (select distinct id from unnest(p_students) u(id)),
  attempts as (
    select c.id as user_id, a.id, a.attempt_no, a.submitted_at,
      case when a.id is null then
        case when exists(select 1 from public.attempts pending where pending.user_id=c.id
          and pending.exam_id=p_exam and pending.status in ('submitted','graded','expired'))
          then 'ungraded' else 'missing' end
        when assessment.review_policy<>'full_review' or a.review_unlocks_at is null
          or a.review_unlocks_at>now() then 'locked' else 'available' end as state
    from chosen c left join lateral (
      select a.* from public.attempts a where a.user_id=c.id and a.exam_id=p_exam
        and a.status in ('submitted','graded','expired') and a.score is not null
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
    join public.questions q on q.id=ids.id and q.track_id='est'
    join public.question_keys k on k.question_id=q.id
    join public.attempt_results r on r.attempt_id=a.id and r.question_id=q.id
    left join public.attempt_answers aa on aa.attempt_id=a.id and aa.question_id=q.id
    where r.is_correct is not null and not coalesce((k.correct->>'void')::boolean,false)
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
  return jsonb_build_object('exam_id',p_exam,'track_id','est','students',students);
end $$;
revoke all on function public.staff_group_exam_evidence(uuid,uuid[]) from public,anon;
grant execute on function public.staff_group_exam_evidence(uuid,uuid[]) to authenticated;
commit;
