-- Evaluate question eligibility once per report, retaining each student's
-- assignment catalogue and latest released result for each distinct question.
create or replace function portal_private.diagnosis_lessons_batch(p_users uuid[],p_track text)
returns table(user_id uuid,lessons jsonb)
language sql stable security definer set search_path='' as $$
 with users as materialized (
  select distinct unnest(p_users) as user_id
 ), exams as materialized (
  select e.* from public.exams e where e.track_id=p_track
 ), attempts as materialized (
  select a.* from public.attempts a join users u on u.user_id=a.user_id
  join exams e on e.id=a.exam_id where a.status in ('submitted','graded','expired')
 ), access as materialized (
  select a.user_id,a.exam_id from public.assignments a join users u on u.user_id=a.user_id
  join exams e on e.id=a.exam_id where e.is_published
  union
  select gm.user_id,a.exam_id from public.assignments a
  join public.group_members gm on gm.group_id=a.group_id join users u on u.user_id=gm.user_id
  join exams e on e.id=a.exam_id where e.is_published
  union
  select a.user_id,a.exam_id from attempts a
 ), catalog_ids as materialized (
  select distinct a.user_id,unnest(e.question_ids) as question_id
  from access a join exams e on e.id=a.exam_id
 ), question_ids as materialized (
  select distinct c.question_id from catalog_ids c
 ), questions as materialized (
  select q.id,coalesce(nullif(btrim(q.assets->>'curriculum_lesson'),''),nullif(btrim(q.topic),''),'Unclassified questions') as lesson
  from question_ids ids join public.questions q on q.id=ids.question_id
  join public.question_keys k on k.question_id=q.id
  where portal_private.question_eligible(q,k,p_track,false)
 ), eligible as materialized (
  select a.* from attempts a join exams e on e.id=a.exam_id
  where a.score is not null and e.review_policy='full_review'
   and a.review_unlocks_at is not null and a.review_unlocks_at<=now()
   and exists(select 1 from public.attempt_answers aa where aa.attempt_id=a.id
    and aa.response is not null and aa.response not in ('null'::jsonb,'""'::jsonb))
 ), latest as materialized (
  select distinct on (a.user_id,r.question_id) a.user_id,r.question_id,r.is_correct,a.submitted_at,
   (aa.response is null or aa.response in ('null'::jsonb,'""'::jsonb)) as blank
  from eligible a join exams e on e.id=a.exam_id
  join public.attempt_results r on r.attempt_id=a.id and r.question_id=any(e.question_ids)
  left join public.attempt_answers aa on aa.attempt_id=a.id and aa.question_id=r.question_id
  where r.is_correct is not null
  order by a.user_id,r.question_id,a.submitted_at desc nulls last,a.attempt_no desc,a.id desc
 ), coverage as (
  select l.user_id,q.lesson,count(*)::int as seen,count(*) filter(where l.is_correct)::int as correct,
   count(*) filter(where not l.is_correct)::int as missed,
   count(*) filter(where not l.is_correct and l.blank)::int as blank,max(l.submitted_at) as last_practiced
  from latest l join questions q on q.id=l.question_id group by l.user_id,q.lesson
 ), catalog as (
  select distinct c.user_id,q.lesson from catalog_ids c join questions q on q.id=c.question_id
 ), ranked as (
  select c.user_id,c.lesson,c.lesson not in ('Mixed / untagged','Unclassified questions') as classified,
   coalesce(v.seen,0) as seen,coalesce(v.correct,0) as correct,coalesce(v.missed,0) as missed,
   coalesce(v.blank,0) as blank,round(100.0*v.correct/nullif(v.seen,0)) as percent,v.last_practiced,
   case when c.lesson in ('Mixed / untagged','Unclassified questions') then 'more_evidence'
    when coalesce(v.seen,0)=0 then 'not_started' when v.seen<3 then 'more_evidence'
    when round(100.0*v.correct/v.seen)<60 then 'focus' when round(100.0*v.correct/v.seen)<80 then 'practice' else 'strong' end as priority
  from catalog c left join coverage v on v.user_id=c.user_id and v.lesson=c.lesson
 ), reports as (
  select r.user_id,jsonb_agg(to_jsonb(r)-'user_id' order by
   case priority when 'focus' then 1 when 'practice' then 2 when 'more_evidence' then 3 when 'not_started' then 4 else 5 end,
   percent nulls last,lesson collate "C") as lessons from ranked r group by r.user_id
 ) select u.user_id,coalesce(r.lessons,'[]'::jsonb) from users u left join reports r on r.user_id=u.user_id;
$$;
revoke all on function portal_private.diagnosis_lessons_batch(uuid[],text) from public,anon,authenticated;
grant execute on function portal_private.diagnosis_lessons_batch(uuid[],text) to service_role;
