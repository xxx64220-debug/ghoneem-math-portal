create or replace view public.daily_quiz_mistakes as
select dp.track_id, dp.day, dp.user_id, p.full_name,
       q.id as question_id, q.topic as lesson, q.stem,
       dp.answers->>q.id::text as submitted_answer,
       k.correct as correct_answer,
       k.explanation
from public.daily_progress dp
join public.profiles p on p.id=dp.user_id
join lateral jsonb_object_keys(dp.answers) a(question_id) on true
join public.questions q on q.id=a.question_id::uuid
join public.question_keys k on k.question_id=q.id
where dp.quiz_completed_at is not null
  and not public.answer_matches(q.type, dp.answers->q.id::text, k.correct)
  and public.staff_can_touch_track(dp.track_id);

alter view public.daily_quiz_mistakes set (security_invoker=true);
revoke all on public.daily_quiz_mistakes from anon;
grant select on public.daily_quiz_mistakes to authenticated;
