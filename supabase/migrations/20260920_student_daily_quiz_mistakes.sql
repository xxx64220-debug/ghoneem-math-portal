create or replace function public.student_daily_quiz_mistakes(p_user uuid, p_track text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  items_ jsonb;
begin
  if not exists (
    select 1
    from public.profiles p
    join public.enrollments e on e.user_id = p.id
    join public.tracks t on t.id = e.track_id
    where p.id = p_user
      and p.role = 'student'
      and p.status = 'active'
      and e.track_id = p_track
      and e.status = 'active'
      and t.is_active
  ) then
    raise exception 'not_enrolled_in_track';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'date', dp.day,
    'question_id', q.id,
    'topic', q.topic,
    'stem', q.stem,
    'choices', q.choices,
    'assets', q.assets,
    'submitted', dp.answers ->> q.id::text,
    'correct', k.correct,
    'explanation', k.explanation
  ) order by dp.day desc, q.id), '[]'::jsonb)
  into items_
  from public.daily_progress dp
  cross join lateral jsonb_object_keys(dp.answers) answer_key(question_id)
  join public.questions q on q.id = answer_key.question_id::uuid
  join public.question_keys k on k.question_id = q.id
  where dp.user_id = p_user
    and dp.track_id = p_track
    and dp.quiz_completed_at is not null
    and not public.answer_matches(q.type, dp.answers -> q.id::text, k.correct);

  return jsonb_build_object(
    'track', p_track,
    'count', jsonb_array_length(items_),
    'items', items_
  );
end;
$$;

revoke all on function public.student_daily_quiz_mistakes(uuid, text) from public, anon, authenticated;
grant execute on function public.student_daily_quiz_mistakes(uuid, text) to service_role;
