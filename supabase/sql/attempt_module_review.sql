CREATE OR REPLACE FUNCTION portal_private.attempt_module_review(p_attempt uuid, p_user uuid, p_include_score_only boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_att public.attempts%rowtype; v_exam public.exams%rowtype;
        v_open boolean; v_items jsonb;
begin
  select * into v_att from public.attempts where id = p_attempt and user_id = p_user;
  if not found then raise exception 'attempt_not_found'; end if;
  if v_att.status = 'in_progress' then
    raise exception 'attempt_still_live';
  end if;
  select * into v_exam from public.exams where id = v_att.exam_id;
  if not public.course_history_access(p_user,v_exam.track_id) then raise exception 'not_enrolled_in_track'; end if;

  v_open := v_att.score is not null and (v_exam.review_policy = 'full_review' or (p_include_score_only and v_exam.track_id='sat' and v_exam.module_number=1 and v_exam.review_policy='score_only'))
            and v_att.review_unlocks_at is not null
            and now() >= v_att.review_unlocks_at;

  select coalesce(jsonb_agg(x order by x ->> 'ord'), '[]'::jsonb) into v_items
    from (
      select jsonb_build_object(
               'id', q.id, 'ord', lpad(u.ord::text, 4, '0'),
               'topic',q.topic,'diagnosis_eligible',v_open and portal_private.question_eligible(q,k,v_exam.track_id,false),
               'type', q.type, 'stem', q.stem, 'choices', q.choices, 'assets', q.assets,
               'response', aa.response,
               'is_correct', r.is_correct,
               'correct',     case when v_open then k.correct     else null end,
               'explanation', case when v_open then k.explanation else null end) as x
        from unnest(v_exam.question_ids) with ordinality as u(qid, ord)
        join public.questions      q on q.id = u.qid
        join public.question_keys  k on k.question_id = q.id
        left join public.attempt_results r on r.attempt_id = p_attempt and r.question_id = q.id
        left join public.attempt_answers aa on aa.attempt_id = p_attempt and aa.question_id = q.id
    ) s;

  return jsonb_build_object(
    'attempt', jsonb_build_object(
        'id', v_att.id, 'status', v_att.status, 'score', v_att.score,
        'scaled_score', v_att.scaled_score, 'total', v_att.total,
        'time_used', v_att.time_used, 'submitted_at', v_att.submitted_at,
        'review_unlocks_at', v_att.review_unlocks_at,
        'answered_count',(select count(*) from public.attempt_answers aa where aa.attempt_id=v_att.id and aa.response is not null and aa.response not in ('null'::jsonb,'""'::jsonb))),
    'exam', jsonb_build_object('title', v_exam.title, 'track_id', v_exam.track_id,
                               'review_policy', v_exam.review_policy),
    'review_open', v_open,
    'items', case when v_open then v_items else '[]'::jsonb end);
end $function$
;
revoke all on function portal_private.attempt_module_review(uuid,uuid,boolean) from public,anon,authenticated;
grant execute on function portal_private.attempt_module_review(uuid,uuid,boolean) to service_role;
