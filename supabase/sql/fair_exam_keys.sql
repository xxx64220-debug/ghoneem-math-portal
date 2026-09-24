-- Accept explicitly recorded alternative MCQ answers; retain grid-in behavior.
create or replace function public.answer_matches(p_type text,p_response jsonb,p_correct jsonb)
returns boolean language plpgsql immutable set search_path=public,extensions as $$
declare r text; rn numeric;
begin
 if p_response is null or p_correct is null or p_correct='null'::jsonb or jsonb_typeof(p_correct)='object' then return false; end if;
 r=btrim(p_response #>> '{}');
 if r is null or r='' then return false; end if;
 if p_type='mcq' then
  return exists(select 1 from jsonb_array_elements_text(
    case when jsonb_typeof(p_correct)='array' then p_correct else jsonb_build_array(p_correct) end) c
    where upper(r)=upper(btrim(c)));
 end if;
 rn=public.norm_num(r);
 return exists(select 1 from jsonb_array_elements_text(
   case when jsonb_typeof(p_correct)='array' then p_correct else jsonb_build_array(p_correct #>> '{}') end) c
   where upper(btrim(c))=upper(r) or (rn is not null and public.norm_num(c) is not null and abs(public.norm_num(c)-rn)<0.000001));
end $$;
revoke execute on function public.answer_matches(text,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.answer_matches(text,jsonb,jsonb) to service_role;

-- Excluded source defects do not enter score totals or lesson accuracy.
CREATE OR REPLACE FUNCTION public.grade_attempt(p_attempt uuid)
 RETURNS attempts
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_att   public.attempts%rowtype;
  v_exam  public.exams%rowtype;
  v_score integer;
  v_total integer;
  v_close timestamptz;
begin
  select * into v_att  from public.attempts where id = p_attempt for update;
  if not found then raise exception 'attempt_not_found'; end if;
  if v_att.status = 'in_progress' then raise exception 'attempt_still_live'; end if;
  select * into v_exam from public.exams    where id = v_att.exam_id;

  -- Missing or unresolved keys must never become a false 0/0 or partial score.
  -- Keep every saved response and the original denominator pending instructor grading.
  if exists (select 1 from unnest(v_exam.question_ids) u(qid)
    left join public.question_keys k on k.question_id=u.qid
    where k.question_id is null or k.correct='null'::jsonb) then
    delete from public.attempt_results where attempt_id=p_attempt;
    update public.attempts set
      status=case when status='expired' then 'expired' else 'submitted' end,
      score=null, scaled_score=null, total=cardinality(v_exam.question_ids),
      time_used=greatest(0,extract(epoch from
        (coalesce(submitted_at,least(clock_timestamp(),deadline_at))-started_at))::int),
      review_unlocks_at=null
    where id=p_attempt returning * into v_att;
    return v_att;
  end if;

  delete from public.attempt_results where attempt_id = p_attempt;

  insert into public.attempt_results(attempt_id, question_id, is_correct, awarded)
  select p_attempt, q.id,
         public.answer_matches(q.type, aa.response, k.correct),
         case when public.answer_matches(q.type, aa.response, k.correct) then 1 else 0 end
    from unnest(v_exam.question_ids) as qid
    join public.questions      q  on q.id = qid
    join public.question_keys  k  on k.question_id = q.id
    left join public.attempt_answers aa
           on aa.attempt_id = p_attempt and aa.question_id = q.id
   where not (k.correct @> '{"void":true}'::jsonb);

  select count(*) filter (where is_correct), count(*)
    into v_score, v_total
    from public.attempt_results where attempt_id = p_attempt;

  select a.close_at into v_close from public.assignments a where a.id = v_att.assignment_id;

  update public.attempts
     set status            = case when status='expired' then 'expired' else 'graded' end,
         score             = v_score,
         total             = v_total,
         -- CHANGED: a scaled score is only meaningful on a full-length paper.
         scaled_score      = case when v_exam.is_full_length and v_total=cardinality(v_exam.question_ids)
                                  then (v_exam.scoring_map ->> v_score::text)::int
                                  else null end,
         time_used         = greatest(0, extract(epoch from
                               (coalesce(submitted_at, now()) - started_at))::int),
         review_unlocks_at = case
                               when v_exam.review_policy = 'instructor_release' then null
                               when v_close is not null and v_close > now() then v_close
                               else now()
                             end
   where id = p_attempt
  returning * into v_att;

  return v_att;
end $function$;


revoke execute on function public.grade_attempt(uuid) from public,anon,authenticated;
grant execute on function public.grade_attempt(uuid) to service_role;
