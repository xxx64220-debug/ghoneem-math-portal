-- Existing SAT/EST question sets include published, keyed items without a
-- verified_release marker. Use those already-live items, excluding holds.
create or replace function public.practice_drill_start(p_user uuid,p_track text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_topics text[]; v_ids uuid[]; v_id uuid;
begin
  if not public.is_enrolled(p_user,p_track) then raise exception 'not_enrolled_in_track'; end if;
  select id into v_id from public.practice_drills where user_id=p_user and track_id=p_track
    and completed_at is null and created_at>now()-interval '1 day' order by created_at desc limit 1;
  if found then return public.practice_drill_state(p_user,p_track,v_id); end if;
  select array_agg(lesson) into v_topics from (
    select lesson from jsonb_to_recordset(public.student_dashboard(p_user,p_track)->'lessons')
      as l(lesson text,seen int,percent numeric)
    where seen>=3 order by percent asc nulls last,lesson limit 3
  ) ranked;
  if cardinality(v_topics) is null then raise exception 'not_enough_topic_history'; end if;
  select array_agg(id) into v_ids from (
    select q.id from public.questions q join public.question_keys k on k.question_id=q.id
    where q.track_id=p_track and q.topic=any(v_topics)
      and (nullif(q.assets->>'verified_release','') is not null or exists (
        select 1 from public.exams e where e.track_id=p_track and e.is_published and q.id=any(e.question_ids)))
      and nullif(q.assets->>'release_hold_reason','') is null
      and jsonb_typeof(k.correct) in ('string','array') and length(btrim(k.explanation))>0
    order by random() limit 18
  ) picked;
  if coalesce(cardinality(v_ids),0)<15 then raise exception 'not_enough_drill_questions'; end if;
  insert into public.practice_drills(user_id,track_id,topics,question_ids)
    values(p_user,p_track,v_topics,v_ids) returning id into v_id;
  return public.practice_drill_state(p_user,p_track,v_id);
end $$;
revoke all on function public.practice_drill_start(uuid,text) from public,anon,authenticated;
grant execute on function public.practice_drill_start(uuid,text) to service_role;
