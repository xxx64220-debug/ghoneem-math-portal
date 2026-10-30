-- Read-only review of the two SAT modules belonging to the selected sitting.
-- The private module renderer is installed from the verified prior definition.
CREATE OR REPLACE FUNCTION public.attempt_review(p_attempt uuid, p_user uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
declare
 base jsonb; first_review jsonb; second_review jsonb;
 selected public.attempts%rowtype; exam_ public.exams%rowtype;
 first_ public.attempts%rowtype; second_ public.attempts%rowtype;
 first_exam public.exams%rowtype; second_exam public.exams%rowtype;
 next_first timestamptz; all_open boolean; scored boolean; release_first boolean;
begin
 -- Retain ownership, course-history, pending-grade and in-progress checks.
 base := portal_private.attempt_module_review(p_attempt,p_user,false);
 select * into selected from public.attempts where id=p_attempt and user_id=p_user;
 select * into exam_ from public.exams where id=selected.exam_id;
 if exam_.track_id<>'sat' or exam_.assessment_type<>'full_exam'
  or exam_.exam_set_code is null or exam_.module_count is distinct from 2
  or exam_.module_number not in (1,2) then return base; end if;
 select * into first_exam from public.exams where track_id='sat'
  and exam_set_code=exam_.exam_set_code and module_number=1 and assessment_type='full_exam';
 select * into second_exam from public.exams where track_id='sat'
  and exam_set_code=exam_.exam_set_code and module_number=2 and assessment_type='full_exam';
 if exam_.module_number=2 then
  second_ := selected;
  -- Pair a Module 2 with the most recent Module 1 completed before it began.
  select * into first_ from public.attempts a where a.user_id=p_user and a.exam_id=first_exam.id
   and a.status in ('submitted','graded','expired')
   and coalesce(a.submitted_at,a.started_at)<=second_.started_at
   order by a.started_at desc,a.attempt_no desc,a.id limit 1;
 else
  first_ := selected;
  select min(a.started_at) into next_first from public.attempts a
   where a.user_id=p_user and a.exam_id=first_exam.id and a.started_at>first_.started_at;
  -- A later Module 1 starts a new sitting. Never borrow its Module 2.
  select * into second_ from public.attempts a where a.user_id=p_user and a.exam_id=second_exam.id
   and a.status in ('submitted','graded','expired')
   and a.started_at>=coalesce(first_.submitted_at,first_.started_at)
   and (next_first is null or a.started_at<next_first)
   order by a.started_at desc,a.attempt_no desc,a.id limit 1;
 end if;
 if first_.id is null or second_.id is null then
  return base || jsonb_build_object('full_exam_pending',true);
 end if;
 second_review := portal_private.attempt_module_review(second_.id,p_user,false);
 -- Legacy Module 1 was score-only. Release its worked answers only after
 -- this sitting's Module 2 has been completed and its own review is open.
 release_first := coalesce((second_review->>'review_open')::boolean,false);
 first_review := portal_private.attempt_module_review(first_.id,p_user,release_first);
 first_review := first_review || jsonb_build_object('module_number',1);
 second_review := second_review || jsonb_build_object('module_number',2);
 all_open := (first_review->>'review_open')::boolean and (second_review->>'review_open')::boolean;
 scored := first_.score is not null and second_.score is not null;
 return jsonb_build_object(
  'full_exam',true,'selected_attempt_id',p_attempt,
  'attempt',jsonb_build_object('id',p_attempt,
   'status',case when not scored then 'submitted' when first_.status='expired' or second_.status='expired' then 'expired' else 'graded' end,
   'score',case when scored then first_.score+second_.score else null end,
   'total',case when first_.total is not null and second_.total is not null then first_.total+second_.total else null end,
   'scaled_score',null,'time_used',coalesce(first_.time_used,0)+coalesce(second_.time_used,0),
   'submitted_at',greatest(first_.submitted_at,second_.submitted_at),
   'review_unlocks_at',case when first_.review_unlocks_at is not null and second_.review_unlocks_at is not null then greatest(first_.review_unlocks_at,second_.review_unlocks_at) else null end,
   'answered_count',coalesce((first_review->'attempt'->>'answered_count')::int,0)+coalesce((second_review->'attempt'->>'answered_count')::int,0)),
  'exam',jsonb_build_object('title',regexp_replace(first_exam.title,'[[:space:]]+[—-][[:space:]]+Module[[:space:]]+1$','','i'),
   'track_id','sat','exam_set_code',exam_.exam_set_code,'review_policy',exam_.review_policy),
  'review_open',all_open,'modules',jsonb_build_array(first_review,second_review),
  'items',case when all_open then (first_review->'items') || (second_review->'items') else '[]'::jsonb end);
end $$;
revoke all on function public.attempt_review(uuid,uuid) from public,anon,authenticated;
grant execute on function public.attempt_review(uuid,uuid) to service_role;
