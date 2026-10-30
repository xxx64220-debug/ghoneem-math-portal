-- Compute readiness once per distinct question and reuse it across the catalog.
-- This service-only RPC retains its existing grants and return fields.
CREATE OR REPLACE FUNCTION public.my_exams(p_user uuid, p_track text)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO public, pg_temp
SET plan_cache_mode TO force_custom_plan
SET jit TO off
SET work_mem TO '16MB'
AS $function$
WITH enrolled AS MATERIALIZED (
 SELECT public.is_enrolled(p_user,p_track) AS active
), memberships AS MATERIALIZED (
 SELECT group_id FROM public.group_members WHERE user_id=p_user
), assigned AS MATERIALIZED (
 SELECT a.exam_id, bool_or((a.open_at IS NULL OR now()>=a.open_at)
   AND (a.close_at IS NULL OR now()<=a.close_at)) AS window_open
 FROM public.assignments a
 WHERE a.user_id=p_user OR a.group_id IN (SELECT group_id FROM memberships)
 GROUP BY a.exam_id
), history AS MATERIALIZED (
 SELECT a.* FROM public.attempts a JOIN public.exams e ON e.id=a.exam_id
 WHERE a.user_id=p_user AND e.track_id=p_track
), visible AS MATERIALIZED (
 SELECT e.*, a.window_open, n.active AS enrolled
 FROM public.exams e JOIN assigned a ON a.exam_id=e.id CROSS JOIN enrolled n
 WHERE e.track_id=p_track AND e.is_published
 AND (n.active OR EXISTS (SELECT 1 FROM history h WHERE h.exam_id=e.id
  AND h.status='in_progress' AND portal_private.attempt_course_access(h.id,p_user,false)))
), requested AS MATERIALIZED (
 SELECT DISTINCT unnest(question_ids) AS id FROM visible
), eligible AS MATERIALIZED (
 -- A scalar lookup keeps large question assets out of hash-join work tables.
 SELECT r.id, (SELECT portal_private.question_eligible(q,k,p_track,false)
  FROM public.questions q LEFT JOIN public.question_keys k ON k.question_id=q.id
  WHERE q.id=r.id OFFSET 0) AS ready FROM requested r
), readiness AS MATERIALIZED (
 SELECT e.id, coalesce(cardinality(e.question_ids),0) BETWEEN 1 AND 200
  AND count(DISTINCT u.id)=cardinality(e.question_ids)
  AND count(*) FILTER (WHERE q.ready)=cardinality(e.question_ids) AS ready
 FROM visible e LEFT JOIN LATERAL unnest(e.question_ids) u(id) ON true
 LEFT JOIN eligible q ON q.id=u.id GROUP BY e.id,e.question_ids
), attempt_counts AS MATERIALIZED (
 SELECT exam_id,count(*) AS total FROM history GROUP BY exam_id
), latest AS MATERIALIZED (
 SELECT DISTINCT ON (a.exam_id) a.exam_id,
  jsonb_build_object('id',a.id,'status',a.status,
   'untimed',a.deadline_at='infinity'::timestamptz,'score',a.score,
   'total',a.total,'scaled_score',a.scaled_score) AS value
 FROM history a ORDER BY a.exam_id,a.attempt_no DESC
), retakes AS MATERIALIZED (
 SELECT DISTINCT exam_id FROM public.retake_grants WHERE user_id=p_user
  AND consumed_at IS NULL AND (expires_at IS NULL OR expires_at>now())
)
SELECT coalesce(jsonb_agg(jsonb_build_object(
 'id',e.id,'title',e.title,'assessment_type',e.assessment_type,
 'duration_seconds',e.duration_seconds,'questions',coalesce(array_length(e.question_ids,1),0),
 'exam_set_code',e.exam_set_code,'module_number',e.module_number,'module_count',e.module_count,
 'content_ready',r.ready,'open',e.enrolled AND e.window_open AND r.ready,
 'attempts',coalesce(a.total,0),
 'max_attempts',CASE WHEN e.assessment_type='lesson_exam' THEN NULL ELSE 1 END,
 'repeatable',e.assessment_type='lesson_exam','allow_untimed',e.assessment_type='lesson_exam',
 'retake_available',e.enrolled AND (e.assessment_type='lesson_exam' OR t.exam_id IS NOT NULL),
 'last',l.value
) ORDER BY e.created_at),'[]'::jsonb)
FROM visible e JOIN readiness r ON r.id=e.id
LEFT JOIN attempt_counts a ON a.exam_id=e.id
LEFT JOIN latest l ON l.exam_id=e.id LEFT JOIN retakes t ON t.exam_id=e.id;
$function$;

