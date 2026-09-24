-- Preserve timed submissions while a complete verified key is unavailable.
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
           on aa.attempt_id = p_attempt and aa.question_id = q.id;

  select count(*) filter (where is_correct), count(*)
    into v_score, v_total
    from public.attempt_results where attempt_id = p_attempt;

  select a.close_at into v_close from public.assignments a where a.id = v_att.assignment_id;

  update public.attempts
     set status            = 'graded',
         score             = v_score,
         total             = v_total,
         -- CHANGED: a scaled score is only meaningful on a full-length paper.
         scaled_score      = case when v_exam.is_full_length
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

CREATE OR REPLACE FUNCTION public.student_dashboard(p_user uuid, p_track text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare history_ jsonb; lessons_ jsonb; summary_ jsonb;
begin
 if not public.is_enrolled(p_user,p_track) then raise exception 'not_enrolled_in_track'; end if;
 select coalesce(jsonb_agg(jsonb_build_object(
  'id',a.id,'exam_id',e.id,'title',e.title,'assessment_type',e.assessment_type,
  'attempt_no',a.attempt_no,'status',a.status,'score',a.score,'total',a.total,
  'percent',round(100.0*a.score/nullif(a.total,0)),'scaled_score',a.scaled_score,
  'submitted_at',a.submitted_at,'time_used',a.time_used,
  'review_open',e.review_policy='full_review' and a.review_unlocks_at is not null and a.review_unlocks_at<=now(),
  'review_unlocks_at',a.review_unlocks_at
 ) order by a.submitted_at desc,a.id),'[]'::jsonb) into history_
 from attempts a join exams e on e.id=a.exam_id
 where a.user_id=p_user and e.track_id=p_track and a.status in ('submitted','graded','expired');

 with eligible as (
  select a.* from attempts a join exams e on e.id=a.exam_id
  where a.user_id=p_user and e.track_id=p_track and a.status in ('submitted','graded','expired')
   and e.review_policy='full_review' and a.review_unlocks_at is not null and a.review_unlocks_at<=now()
 ), latest as (
  select distinct on (r.question_id) r.question_id,r.is_correct,a.submitted_at
  from eligible a join attempt_results r on r.attempt_id=a.id
  order by r.question_id,a.submitted_at desc,a.attempt_no desc,a.id
 ), coverage as (
  select coalesce(nullif(btrim(q.topic),''),'Mixed / untagged') as lesson,
  count(*) as seen,count(*) filter(where l.is_correct) as correct,
  max(l.submitted_at) as last_practiced
  from latest l join questions q on q.id=l.question_id
  where q.track_id=p_track
  group by 1
 ), catalog as (
  select distinct coalesce(nullif(btrim(q.topic),''),'Mixed / untagged') as lesson
  from exams e cross join lateral unnest(e.question_ids) as eq(question_id) join questions q on q.id=eq.question_id
  where e.track_id=p_track and q.track_id=p_track
   and ((e.is_published and exam_assigned_to(e.id,p_user)) or exists(select 1 from attempts a where a.exam_id=e.id and a.user_id=p_user and a.status in ('submitted','graded','expired')))
 ), ranked as (
  select c.lesson,coalesce(v.seen,0) as seen,coalesce(v.correct,0) as correct,
   round(100.0*v.correct/nullif(v.seen,0)) as percent,v.last_practiced,
   case when coalesce(v.seen,0)=0 then 'not_started' when v.seen<3 then 'more_evidence'
    when 100.0*v.correct/v.seen<60 then 'focus' when 100.0*v.correct/v.seen<80 then 'practice' else 'strong' end as priority
  from catalog c left join coverage v on v.lesson=c.lesson
 ) select coalesce(jsonb_agg(to_jsonb(r) order by
  case priority when 'focus' then 1 when 'practice' then 2 when 'more_evidence' then 3 when 'not_started' then 4 else 5 end,
  percent nulls last,lesson),'[]'::jsonb) into lessons_ from ranked r;

 select jsonb_build_object('completed',count(*),'average_percent',round(avg(100.0*a.score/nullif(a.total,0))),
 'best_percent',round(max(100.0*a.score/nullif(a.total,0))),
 'questions_answered',coalesce(sum(a.total),0),
 'lessons_to_focus',(select count(*) from jsonb_array_elements(lessons_) l where l->>'priority'='focus'),
 'review_pending',count(*) filter(where not(e.review_policy='full_review' and a.review_unlocks_at is not null and a.review_unlocks_at<=now())))
 into summary_ from attempts a join exams e on e.id=a.exam_id where a.user_id=p_user and e.track_id=p_track and a.status in ('submitted','graded','expired');
 return jsonb_build_object('summary',summary_,'history',history_,'lessons',lessons_);
end $function$;

CREATE OR REPLACE FUNCTION public.attempt_review(p_attempt uuid, p_user uuid)
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
  if not public.is_enrolled(p_user,v_exam.track_id) then raise exception 'not_enrolled_in_track'; end if;

  v_open := v_att.score is not null and v_exam.review_policy = 'full_review'
            and v_att.review_unlocks_at is not null
            and now() >= v_att.review_unlocks_at;

  select coalesce(jsonb_agg(x order by x ->> 'ord'), '[]'::jsonb) into v_items
    from (
      select jsonb_build_object(
               'id', q.id, 'ord', lpad(u.ord::text, 4, '0'),
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
        'review_unlocks_at', v_att.review_unlocks_at),
    'exam', jsonb_build_object('title', v_exam.title, 'track_id', v_exam.track_id,
                               'review_policy', v_exam.review_policy),
    'review_open', v_open,
    'items', case when v_open then v_items else '[]'::jsonb end);
end $function$;

revoke execute on function public.grade_attempt(uuid), public.student_dashboard(uuid,text), public.attempt_review(uuid,uuid) from public,anon,authenticated;
grant execute on function public.grade_attempt(uuid), public.student_dashboard(uuid,text), public.attempt_review(uuid,uuid) to service_role;

create or replace view public.results_feed with(security_invoker=true) as
 select a.id as attempt_id,a.user_id,p.full_name,e.track_id,e.title as exam,a.status,a.score,a.total,a.scaled_score,
 round(100.0*a.score/nullif(a.total,0)) as percent,a.time_used,a.submitted_at,e.is_full_length,e.id as exam_id
 from attempts a join exams e on e.id=a.exam_id join profiles p on p.id=a.user_id
 where a.status in ('submitted','graded','expired') and staff_can_touch_track(e.track_id) order by a.submitted_at desc;
