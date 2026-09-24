-- Backfill already ran with the initial two-argument function. Replace it with
-- a bounded, paged response so large question banks do not freeze student phones.
drop function if exists public.practice_notebook_state(uuid,text);
create or replace function public.practice_notebook_state(p_user uuid,p_track text,p_offset integer)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_items jsonb; v_count int; v_done int;
begin
  if not public.is_enrolled(p_user,p_track) then raise exception 'not_enrolled_in_track'; end if;
  if p_offset<0 or p_offset>10000 then raise exception 'invalid_page'; end if;
  insert into public.practice_notebook(user_id,question_id)
  select distinct p_user,r.question_id from public.attempt_results r
  join public.attempts a on a.id=r.attempt_id join public.exams e on e.id=a.exam_id
  join public.questions q on q.id=r.question_id and q.track_id=e.track_id
  join public.question_keys k on k.question_id=q.id
  where a.user_id=p_user and e.track_id=p_track and r.is_correct=false
    and a.status in ('graded','expired') and a.score is not null
    and e.review_policy='full_review' and a.review_unlocks_at<=now()
    and jsonb_typeof(k.correct) in ('string','array') on conflict do nothing;
  insert into public.practice_notebook(user_id,question_id)
  select distinct p_user,q.id from public.daily_progress dp
  cross join lateral jsonb_each(dp.answers) answer_(qid,response)
  join public.questions q on q.id=answer_.qid::uuid and q.track_id=dp.track_id
  join public.question_keys k on k.question_id=q.id
  where dp.user_id=p_user and dp.track_id=p_track and dp.quiz_completed_at is not null
    and not public.answer_matches(q.type,answer_.response,k.correct)
    and jsonb_typeof(k.correct) in ('string','array') on conflict do nothing;
  select count(*) filter(where n.correct_streak<2),count(*) filter(where n.correct_streak=2)
    into v_count,v_done from public.practice_notebook n join public.questions q on q.id=n.question_id
    where n.user_id=p_user and q.track_id=p_track;
  select coalesce(jsonb_agg(jsonb_build_object('id',q.id,'stem',q.stem,'topic',q.topic,
    'type',q.type,'choices',q.choices,'assets',q.assets,'streak',n.correct_streak,'tries',n.tries)
    order by q.topic,q.id),'[]'::jsonb) into v_items
  from (select n.question_id,n.correct_streak,n.tries,n.updated_at
    from public.practice_notebook n join public.questions page_q on page_q.id=n.question_id
    where n.user_id=p_user and page_q.track_id=p_track and n.correct_streak<2
    order by page_q.topic,n.question_id limit 25 offset p_offset) n
  join public.questions q on q.id=n.question_id;
  return jsonb_build_object('track',p_track,'remaining',v_count,'mastered',v_done,'items',v_items,'offset',p_offset);
end $$;
revoke all on function public.practice_notebook_state(uuid,text,integer) from public,anon,authenticated;
grant execute on function public.practice_notebook_state(uuid,text,integer) to service_role;
