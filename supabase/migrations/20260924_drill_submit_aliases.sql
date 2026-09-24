-- Qualify the unnest column to avoid ambiguous id references during grading.
create or replace function public.practice_drill_submit(p_user uuid,p_track text,p_drill uuid,p_answers jsonb)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_drill public.practice_drills%rowtype; v_score int;
begin
  if not public.is_enrolled(p_user,p_track) then raise exception 'not_enrolled_in_track'; end if;
  select * into v_drill from public.practice_drills
    where id=p_drill and user_id=p_user and track_id=p_track for update;
  if not found then raise exception 'drill_not_found'; end if;
  if v_drill.completed_at is not null then return public.practice_drill_state(p_user,p_track,p_drill); end if;
  if jsonb_typeof(p_answers) is distinct from 'object'
    or (select count(*) from jsonb_object_keys(p_answers))<>cardinality(v_drill.question_ids)
    or exists(select 1 from jsonb_object_keys(p_answers) as answer_key(qid)
      where not answer_key.qid=any(select unnest(v_drill.question_ids)::text))
    or exists(select 1 from unnest(v_drill.question_ids) as selected(qid)
      join public.questions q on q.id=selected.qid
      where jsonb_typeof(p_answers->selected.qid::text) is distinct from 'string'
      or length(p_answers->>selected.qid::text)>250 or length(p_answers->>selected.qid::text)=0
      or (q.type='mcq' and not exists(select 1 from jsonb_array_elements(q.choices) c
        where c->>'key'=p_answers->>selected.qid::text)))
  then raise exception 'invalid_answers'; end if;
  select count(*) into v_score from unnest(v_drill.question_ids) as selected(qid)
    join public.questions q on q.id=selected.qid join public.question_keys k on k.question_id=q.id
    where public.answer_matches(q.type,p_answers->selected.qid::text,k.correct);
  update public.practice_drills set answers=p_answers,score=v_score,completed_at=now() where id=p_drill;
  return public.practice_drill_state(p_user,p_track,p_drill);
end $$;
revoke all on function public.practice_drill_submit(uuid,text,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.practice_drill_submit(uuid,text,uuid,jsonb) to service_role;
