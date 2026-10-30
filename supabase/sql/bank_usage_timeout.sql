-- Keep wide question/image records out of the report's evidence joins.
-- Specialize the plan for this course, role and optional group/cycle filters.
-- The function body preserves all authorization, readiness and scoring rules.
CREATE OR REPLACE FUNCTION portal_private.staff_bank_operations(p_track text, p_group uuid DEFAULT NULL::uuid, p_cycle uuid DEFAULT NULL::uuid, p_filter text DEFAULT 'all'::text, p_page integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
 SET plan_cache_mode TO 'force_custom_plan'
AS $function$
declare role_ text; start_ timestamptz:='-infinity';end_ timestamptz:='infinity';result_ jsonb;
begin
 role_:=portal_private.require_course_staff(p_track,p_group);
 if p_filter is null or p_filter not in ('all','unused','underused','hardest','held','pending','reserve') or p_page is null or p_page not between 0 and 100000 then raise exception 'invalid_filter';end if;
 if p_cycle is not null then
 select starts_at,coalesce(ends_at,'infinity') into start_,end_ from public.hardest_cycles where id=p_cycle and track_id=p_track;
 if not found then raise exception 'cycle_track_mismatch';end if;end if;
 with bank_content as materialized(
 select q.id,q.topic lesson,left(q.stem,160) stem,q.difficulty,md5(coalesce(to_jsonb(c)::text,'{}')) assets_hash,
 coalesce(q.assets->>'source_code',q.id::text) code,
 portal_private.question_eligible(q,k,p_track,false) ready,coalesce(q.assets->>'release_hold_reason','') hold_reason,
 coalesce(q.assets->>'answer_review_status','') math_review,
 coalesce(c.reserve,false) reserve
 from public.questions q left join public.question_catalogue c on c.question_id=q.id
 left join public.question_keys k on k.question_id=q.id
 where q.track_id=p_track and coalesce(q.assets->>'bank_removed','false')<>'true'
 ),learners as materialized(
 select p.id from public.profiles p where p.role='student' and not p.is_test
 and (exists(select 1 from public.enrollments en where en.user_id=p.id and en.track_id=p_track)
 or exists(select 1 from public.attempts a join public.exams e on e.id=a.exam_id where a.user_id=p.id and e.track_id=p_track)
 or exists(select 1 from public.daily_progress d where d.user_id=p.id and d.track_id=p_track))
 and (role_='admin' or exists(select 1 from public.group_members gm join public.groups g on g.id=gm.group_id
 where gm.user_id=p.id and g.track_id=p_track and g.instructor_id=auth.uid()))
 and (p_group is null or exists(select 1 from public.group_members gm where gm.user_id=p.id and gm.group_id=p_group))
 ),events as materialized(
 select r.question_id,a.user_id,r.is_correct,a.started_at at_,a.id::text||':'||r.question_id::text event_
 from public.attempt_results r join public.attempts a on a.id=r.attempt_id join public.exams e on e.id=a.exam_id
 join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id
 where e.track_id=p_track and q.track_id=p_track and a.user_id in(select id from learners)
 and a.status in ('submitted','graded','expired') and a.score is not null and r.is_correct is not null
 and coalesce(k.correct->>'void','false')<>'true' and a.started_at>=start_ and a.started_at<end_
 union all
 select q.id,d.user_id,public.answer_matches(q.type,d.answers->q.id::text,k.correct),d.quiz_completed_at,
 d.user_id::text||':'||d.track_id||':'||d.day::text||':'||q.id::text
 from public.daily_progress d cross join lateral jsonb_object_keys(d.answers) x(id)
 join public.questions q on q.id::text=x.id join public.question_keys k on k.question_id=q.id
 where d.track_id=p_track and q.track_id=p_track and d.user_id in(select id from learners)
 and d.quiz_completed_at is not null and d.quiz_score is not null and coalesce(k.correct->>'void','false')<>'true'
 and d.answers->x.id is not null and jsonb_typeof(d.answers->x.id)<>'null'
 and d.quiz_completed_at>=start_ and d.quiz_completed_at<end_
 ),per_student as materialized(
 select question_id,user_id,count(*) responses,(array_agg(is_correct order by at_,event_))[1] first_correct,
 (array_agg(is_correct order by at_ desc,event_ desc))[1] latest_correct,max(at_) last_used
 from events group by question_id,user_id
 ),metrics as materialized(
 select question_id,count(*)::int unique_students,sum(responses)::int responses,
 count(*) filter(where first_correct)::int first_correct,count(*) filter(where latest_correct)::int latest_correct,
 count(*) filter(where not first_correct and responses>1)::int repeat_candidates,
 count(*) filter(where not first_correct and responses>1 and latest_correct)::int improved,max(last_used) last_used
 from per_student group by question_id
 ),exposure as materialized(
 select qid,count(distinct e.id)::int published_exams,count(distinct a.id)::int assignments
 from public.exams e cross join lateral unnest(e.question_ids) qid left join public.assignments a on a.exam_id=e.id
 and (p_group is null or a.group_id=p_group or a.user_id in(select id from learners))
 and (role_='admin' or a.user_id in(select id from learners) or exists(select 1 from public.groups ag where ag.id=a.group_id and ag.track_id=p_track and ag.instructor_id=auth.uid()))
 where e.track_id=p_track and e.is_published and (role_='admin' or exists(select 1 from public.assignments a2 where a2.exam_id=e.id
 and (a2.user_id in(select id from learners) or exists(select 1 from public.groups g where g.id=a2.group_id and g.instructor_id=auth.uid() and g.track_id=p_track))))
 group by qid
 ),bank as materialized(
 select q.*,
 coalesce(m.unique_students,0) unique_students,coalesce(m.responses,0) responses,
 round(100.0*m.first_correct/nullif(m.unique_students,0),1) first_success,
 round(100.0*m.latest_correct/nullif(m.unique_students,0),1) latest_success,
 coalesce(m.repeat_candidates,0) repeat_candidates,coalesce(m.improved,0) improved,
 round(100.0*m.improved/nullif(m.repeat_candidates,0),1) repeat_improvement,m.last_used,
 coalesce(x.published_exams,0) published_exams,coalesce(x.assignments,0) assignments
 from bank_content q left join metrics m on m.question_id=q.id
 left join exposure x on x.qid=q.id
 ),filtered as(select * from bank where p_filter='all' or (p_filter='unused' and ready and not reserve and assignments=0 and responses=0)
 or (p_filter='underused' and ready and assignments>0 and unique_students<3) or (p_filter='hardest' and unique_students>0)
 or (p_filter='held' and not ready) or (p_filter='pending' and math_review<>'independently_solved') or (p_filter='reserve' and reserve)),
 page_ as(select * from filtered order by case when p_filter='hardest' then first_success end asc nulls last,
 case when p_filter='hardest' then unique_students end desc,lesson,id limit 50 offset p_page*50)
 select jsonb_build_object('track',p_track,'group',p_group,'cycle',p_cycle,'total',(select count(*) from filtered),'page',p_page,
 'items',coalesce((select jsonb_agg(to_jsonb(p) order by case when p_filter='hardest' then first_success end asc nulls last,
 case when p_filter='hardest' then unique_students end desc,lesson,id) from page_ p),'[]'::jsonb),
 'summary',jsonb_build_object('total',(select count(*) from bank),'unused',(select count(*) from bank where ready and not reserve and assignments=0 and responses=0),
 'held',(select count(*) from bank where not ready),'reserve',(select count(*) from bank where reserve),'students',(select count(*) from learners))) into result_;
 return result_;
end $function$;
