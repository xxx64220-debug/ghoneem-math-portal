-- Apply diagnosis_batch.sql first. One evidence rule for student and staff diagnosis.
create or replace function portal_private.diagnosis_lessons(p_user uuid,p_track text)
returns jsonb language sql stable security definer set search_path='' as $$
 with accessible_exams as materialized (
  -- Resolve expensive assignment permissions once per exam, before unnesting.
  select e.id,e.question_ids from public.exams e where e.track_id=p_track
   and ((e.is_published and public.exam_assigned_to(e.id,p_user)) or exists(
    select 1 from public.attempts a where a.exam_id=e.id and a.user_id=p_user and a.status in ('submitted','graded','expired')))
 ), catalog_ids as materialized (
  select distinct unnest(question_ids) as question_id from accessible_exams
 ), eligible as materialized (
  select a.* from public.attempts a join public.exams e on e.id=a.exam_id
  where a.user_id=p_user and e.track_id=p_track and a.status in ('submitted','graded','expired')
   and a.score is not null and e.review_policy='full_review'
   and a.review_unlocks_at is not null and a.review_unlocks_at<=now()
   and exists(select 1 from public.attempt_answers aa where aa.attempt_id=a.id
    and aa.response is not null and aa.response not in ('null'::jsonb,'""'::jsonb))
 ), latest as materialized (
  select distinct on (r.question_id) r.question_id,r.is_correct,a.submitted_at,
   (aa.response is null or aa.response in ('null'::jsonb,'""'::jsonb)) as blank
  from eligible a join public.exams e on e.id=a.exam_id
  join public.attempt_results r on r.attempt_id=a.id and r.question_id=any(e.question_ids)
  left join public.attempt_answers aa on aa.attempt_id=a.id and aa.question_id=r.question_id
  where r.is_correct is not null
  order by r.question_id,a.submitted_at desc nulls last,a.attempt_no desc,a.id desc
 ), coverage as (
  select coalesce(nullif(btrim(q.assets->>'curriculum_lesson'),''),nullif(btrim(q.topic),''),'Unclassified questions') as lesson,
   count(*)::int as seen,count(*) filter(where l.is_correct)::int as correct,
   count(*) filter(where not l.is_correct)::int as missed,
   count(*) filter(where not l.is_correct and l.blank)::int as blank,max(l.submitted_at) as last_practiced
  from latest l join public.questions q on q.id=l.question_id join public.question_keys k on k.question_id=q.id
  where portal_private.question_eligible(q,k,p_track,false) group by 1
 ), catalog as (
  select distinct coalesce(nullif(btrim(q.assets->>'curriculum_lesson'),''),nullif(btrim(q.topic),''),'Unclassified questions') as lesson
  from catalog_ids eq join public.questions q on q.id=eq.question_id join public.question_keys k on k.question_id=q.id
  where portal_private.question_eligible(q,k,p_track,false)
 ), ranked as (
  select c.lesson,c.lesson not in ('Mixed / untagged','Unclassified questions') as classified,
   coalesce(v.seen,0) as seen,coalesce(v.correct,0) as correct,coalesce(v.missed,0) as missed,
   coalesce(v.blank,0) as blank,round(100.0*v.correct/nullif(v.seen,0)) as percent,v.last_practiced,
   case when c.lesson in ('Mixed / untagged','Unclassified questions') then 'more_evidence'
    when coalesce(v.seen,0)=0 then 'not_started' when v.seen<3 then 'more_evidence'
    when round(100.0*v.correct/v.seen)<60 then 'focus' when round(100.0*v.correct/v.seen)<80 then 'practice' else 'strong' end as priority
  from catalog c left join coverage v on v.lesson=c.lesson
 ) select coalesce(jsonb_agg(to_jsonb(r) order by
  case priority when 'focus' then 1 when 'practice' then 2 when 'more_evidence' then 3 when 'not_started' then 4 else 5 end,
  percent nulls last,lesson collate "C"),'[]'::jsonb) from ranked r;
$$;

-- Daily scores retain their original group and recorded grade. They are never
-- blended into exam lesson accuracy or regraded using today's keys.
create or replace function portal_private.diagnosis_daily(p_user uuid,p_track text,p_staff uuid default null)
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(to_jsonb(s) order by s.group_name,s.group_id),'[]'::jsonb) from (
  select dp.quiz_group_id as group_id,coalesce(g.name,'Earlier course quiz') as group_name,
   count(*)::int as completed,round(avg(dp.quiz_score),2) as average_score,
   (array_agg(dp.quiz_score order by dp.day desc))[1] as latest_score,max(dp.day) as latest_day
  from public.daily_progress dp left join public.groups g on g.id=dp.quiz_group_id
  where dp.user_id=p_user and dp.track_id=p_track and dp.quiz_completed_at is not null and dp.quiz_score is not null
   and (dp.quiz_group_id is null or g.track_id=p_track)
   and (p_staff is null or public.is_admin() or g.instructor_id=p_staff
    or (dp.quiz_group_id is null and exists(select 1 from public.groups owned
     join public.group_members gm on gm.group_id=owned.id
     where owned.track_id=p_track and owned.instructor_id=p_staff and gm.user_id=p_user)))
  group by dp.quiz_group_id,g.name
 ) s;
$$;
revoke all on function portal_private.diagnosis_lessons(uuid,text),portal_private.diagnosis_daily(uuid,text,uuid) from public,anon,authenticated;
grant execute on function portal_private.diagnosis_lessons(uuid,text),portal_private.diagnosis_daily(uuid,text,uuid) to service_role;

create or replace function public.staff_diagnosis(p_track text)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare students jsonb;
begin
 if auth.uid() is null or not coalesce(public.is_staff(),false) then raise exception 'staff_required' using errcode='42501'; end if;
 if p_track not in ('sat','est','est2','est_eng') or p_track is null
  or not coalesce(public.staff_can_touch_track(p_track),false) then raise exception 'track_scope_denied' using errcode='42501'; end if;
 with roster as materialized (
  select p.* from public.profiles p join public.enrollments en on en.user_id=p.id and en.track_id=p_track
  where p.role='student' and public.course_history_access(p.id,p_track)
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
end $$;
revoke all on function public.staff_diagnosis(text) from public,anon;
grant execute on function public.staff_diagnosis(text) to authenticated;
