-- DRAFT: apply only after approval, after practice_bundle_hierarchy.sql.
-- No changes to exam results, assignments, quiz points or Today completion rules.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
do $$ begin
 if md5(pg_get_functiondef('public.practice_bundle_save(uuid,text,uuid,integer,jsonb,integer,boolean)'::regprocedure)) <> '111e65936c386556a801703bd5a78a69' then raise exception 'bundle_integration_source_changed: save'; end if;
 if md5(pg_get_functiondef('portal_private.record_notebook_activity()'::regprocedure)) <> '2624d3fc3d883a48804868ad4faded30' then raise exception 'bundle_integration_source_changed: notebook activity'; end if;
 if md5(pg_get_functiondef('portal_private.diagnosis_lessons(uuid,text)'::regprocedure)) <> 'cadabd635327a71de8b0195b046fb253' then raise exception 'bundle_integration_source_changed: portal_private.diagnosis_lessons'; end if;
 if md5(pg_get_functiondef('portal_private.diagnosis_lessons_batch(uuid[],text)'::regprocedure)) <> 'bfb7396412ddd819ee3ec87efe0ab250' then raise exception 'bundle_integration_source_changed: portal_private.diagnosis_lessons_batch'; end if;
 if to_regprocedure('portal_private.bundle_evidence(uuid[],text)') is not null then raise exception 'bundle_integration_already_installed'; end if;
end $$;

-- Grade the immutable snapshot the learner answered, but use it for current
-- recommendations only while the corresponding bank version remains eligible.
create function portal_private.bundle_evidence(p_users uuid[],p_track text)
returns table(user_id uuid,question_id uuid,is_correct boolean,submitted_at timestamptz,bundle_id uuid)
language sql stable security definer set search_path='' as $$
 select b.user_id,i.question_id,public.answer_matches(i.payload->>'type',b.answers->i.question_id::text,i.correct),b.completed_at,b.id
 from public.practice_bundles b join public.practice_bundle_items i on i.bundle_id=b.id
 join public.questions q on q.id=i.question_id join public.question_keys k on k.question_id=q.id
 where b.user_id=any(p_users) and b.track_id=p_track and b.completed_at is not null and b.score is not null
 and nullif(btrim(b.answers->>i.question_id::text),'') is not null
 and portal_private.question_eligible(q,k,p_track,false)
 and not exists(select 1 from public.question_catalogue c where c.question_id=q.id and c.reserve)
 and i.fingerprint=md5(jsonb_build_array(q.stem,q.type,q.choices,q.assets,k.correct,k.explanation)::text);
$$;
revoke all on function portal_private.bundle_evidence(uuid[],text) from public,anon,authenticated;
grant execute on function portal_private.bundle_evidence(uuid[],text) to service_role;

-- Insert mistakes only on the first submission; autosaves/retries cannot reset mastery.
-- Do not increment tries: importing a mistake is not notebook practice or a Today task.
create function portal_private.bundle_to_notebook() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 insert into public.practice_notebook(user_id,question_id,correct_streak,tries,updated_at)
 select e.user_id,e.question_id,0,0,e.submitted_at from portal_private.bundle_evidence(array[new.user_id],new.track_id) e
 where e.bundle_id=new.id and not e.is_correct
 on conflict(user_id,question_id) do update set correct_streak=0,updated_at=excluded.updated_at
 where public.practice_notebook.updated_at <= excluded.updated_at;
 return new;
end $$;
revoke all on function portal_private.bundle_to_notebook() from public,anon,authenticated;
create trigger completed_bundle_notebook after update of completed_at on public.practice_bundles
 for each row when(old.completed_at is null and new.completed_at is not null)
 execute function portal_private.bundle_to_notebook();

-- Import earlier completed practice once, without undoing a newer notebook correction.
insert into public.practice_notebook(user_id,question_id,correct_streak,tries,updated_at)
select e.user_id,e.question_id,0,0,e.submitted_at from (
 select distinct on (e.user_id,e.question_id) e.*
 from (select track_id,array_agg(distinct user_id) as users from public.practice_bundles where completed_at is not null group by track_id) b
 cross join lateral portal_private.bundle_evidence(b.users,b.track_id) e
 order by e.user_id,e.question_id,e.submitted_at desc,e.bundle_id desc
) e where not e.is_correct
on conflict(user_id,question_id) do update set correct_streak=0,updated_at=excluded.updated_at
where public.practice_notebook.updated_at <= excluded.updated_at;

create or replace function portal_private.diagnosis_lessons_batch(p_users uuid[],p_track text)
returns table(user_id uuid,lessons jsonb)
language sql stable security definer set search_path='' as $$
 with users as materialized (
  select distinct unnest(p_users) as user_id
 ), bundles as materialized (
  select * from portal_private.bundle_evidence(p_users,p_track)
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
  union select b.user_id,b.question_id from bundles b
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
 ), evidence as (
  select a.user_id,r.question_id,r.is_correct,a.submitted_at,
   (aa.response is null or aa.response in ('null'::jsonb,'""'::jsonb)) as blank,
   'exam'::text as source,a.attempt_no as ordinal,a.id
  from eligible a join exams e on e.id=a.exam_id
  join public.attempt_results r on r.attempt_id=a.id and r.question_id=any(e.question_ids)
  left join public.attempt_answers aa on aa.attempt_id=a.id and aa.question_id=r.question_id
  where r.is_correct is not null
  union all
  select b.user_id,b.question_id,b.is_correct,b.submitted_at,false,'bundle',0,b.bundle_id from bundles b
 ), latest as materialized (
  select distinct on (user_id,question_id) * from evidence
  order by user_id,question_id,submitted_at desc nulls last,source desc,ordinal desc,id desc
 ), coverage as (
  select l.user_id,q.lesson,count(*)::int as seen,count(*) filter(where l.is_correct)::int as correct,
   count(*) filter(where not l.is_correct)::int as missed,
   count(*) filter(where l.source='bundle')::int as bundle_seen,count(*) filter(where l.source='exam')::int as exam_seen,
   count(*) filter(where not l.is_correct and l.blank)::int as blank,max(l.submitted_at) as last_practiced
  from latest l join questions q on q.id=l.question_id group by l.user_id,q.lesson
 ), catalog as (
  select distinct c.user_id,q.lesson from catalog_ids c join questions q on q.id=c.question_id
 ), ranked as (
  select c.user_id,c.lesson,c.lesson not in ('Mixed / untagged','Unclassified questions') as classified,
   coalesce(v.seen,0) as seen,coalesce(v.correct,0) as correct,coalesce(v.missed,0) as missed,
   coalesce(v.bundle_seen,0) as bundle_seen,coalesce(v.exam_seen,0) as exam_seen,coalesce(v.blank,0) as blank,round(100.0*v.correct/nullif(v.seen,0)) as percent,v.last_practiced,
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

-- Student and instructor use exactly the same distinct-question evidence rules.
create or replace function portal_private.diagnosis_lessons(p_user uuid,p_track text) returns jsonb
language sql stable security definer set search_path='' as $$
 select lessons from portal_private.diagnosis_lessons_batch(array[p_user],p_track);
$$;
revoke all on function portal_private.diagnosis_lessons(uuid,text) from public,anon,authenticated;
grant execute on function portal_private.diagnosis_lessons(uuid,text) to service_role;
commit;
