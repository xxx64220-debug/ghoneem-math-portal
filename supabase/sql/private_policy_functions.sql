-- Move privileged bodies outside the exposed API schema without changing OIDs.
-- Existing RLS dependencies follow ALTER FUNCTION; server-only compatibility
-- wrappers keep Edge Function and stored-function calls working.

ALTER FUNCTION public.act2_collection_search(text,text,text) SET SCHEMA portal_private;
ALTER FUNCTION portal_private.act2_collection_search(text,text,text) SET search_path TO '';
CREATE FUNCTION public.act2_collection_search(p_search text DEFAULT ''::text, p_category text DEFAULT ''::text, p_subject text DEFAULT ''::text) RETURNS jsonb
LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO ''
AS $wrapper$ SELECT portal_private.act2_collection_search(p_search,p_category,p_subject); $wrapper$;
REVOKE ALL ON FUNCTION public.act2_collection_search(text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.act2_collection_search(text,text,text) TO authenticated,service_role;
REVOKE ALL ON FUNCTION portal_private.act2_collection_search(text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION portal_private.act2_collection_search(text,text,text) TO authenticated,service_role;

ALTER FUNCTION public.act2_collection_staff() SET SCHEMA portal_private;
ALTER FUNCTION portal_private.act2_collection_staff() SET search_path TO '';
CREATE FUNCTION public.act2_collection_staff() RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO ''
AS $wrapper$ SELECT portal_private.act2_collection_staff(); $wrapper$;
REVOKE ALL ON FUNCTION public.act2_collection_staff() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.act2_collection_staff() TO service_role;
REVOKE ALL ON FUNCTION portal_private.act2_collection_staff() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION portal_private.act2_collection_staff() TO authenticated,service_role;

ALTER FUNCTION public.admin_bank_page(text,text,text,text,text,text,integer,integer) SET SCHEMA portal_private;
ALTER FUNCTION portal_private.admin_bank_page(text,text,text,text,text,text,integer,integer) SET search_path TO '';
CREATE FUNCTION public.admin_bank_page(p_track text, p_scope text DEFAULT 'questions'::text, p_search text DEFAULT ''::text, p_lesson text DEFAULT ''::text, p_status text DEFAULT ''::text, p_sort text DEFAULT 'priority'::text, p_page integer DEFAULT 0, p_size integer DEFAULT 50) RETURNS jsonb
LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO ''
AS $wrapper$ SELECT portal_private.admin_bank_page(p_track,p_scope,p_search,p_lesson,p_status,p_sort,p_page,p_size); $wrapper$;
REVOKE ALL ON FUNCTION public.admin_bank_page(text,text,text,text,text,text,integer,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.admin_bank_page(text,text,text,text,text,text,integer,integer) TO authenticated,service_role;
REVOKE ALL ON FUNCTION portal_private.admin_bank_page(text,text,text,text,text,text,integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION portal_private.admin_bank_page(text,text,text,text,text,text,integer,integer) TO authenticated,service_role;

ALTER FUNCTION public.attempt_is_mine(uuid,uuid) SET SCHEMA portal_private;
ALTER FUNCTION portal_private.attempt_is_mine(uuid,uuid) SET search_path TO public,pg_temp;
CREATE FUNCTION public.attempt_is_mine(p_attempt uuid, p_user uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO ''
AS $wrapper$ SELECT portal_private.attempt_is_mine(p_attempt,p_user); $wrapper$;
REVOKE ALL ON FUNCTION public.attempt_is_mine(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.attempt_is_mine(uuid,uuid) TO service_role;
REVOKE ALL ON FUNCTION portal_private.attempt_is_mine(uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION portal_private.attempt_is_mine(uuid,uuid) TO authenticated,service_role;

ALTER FUNCTION public.attempt_live_for(uuid,uuid) SET SCHEMA portal_private;
ALTER FUNCTION portal_private.attempt_live_for(uuid,uuid) SET search_path TO public,pg_temp;
CREATE FUNCTION public.attempt_live_for(p_attempt uuid, p_user uuid) RETURNS boolean
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path TO ''
AS $wrapper$ SELECT portal_private.attempt_live_for(p_attempt,p_user); $wrapper$;
REVOKE ALL ON FUNCTION public.attempt_live_for(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.attempt_live_for(uuid,uuid) TO service_role;
REVOKE ALL ON FUNCTION portal_private.attempt_live_for(uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION portal_private.attempt_live_for(uuid,uuid) TO authenticated,service_role;

ALTER FUNCTION public.attempt_review_open(uuid,uuid) SET SCHEMA portal_private;
ALTER FUNCTION portal_private.attempt_review_open(uuid,uuid) SET search_path TO public,pg_temp;
CREATE FUNCTION public.attempt_review_open(p_attempt uuid, p_user uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO ''
AS $wrapper$ SELECT portal_private.attempt_review_open(p_attempt,p_user); $wrapper$;
REVOKE ALL ON FUNCTION public.attempt_review_open(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.attempt_review_open(uuid,uuid) TO service_role;
REVOKE ALL ON FUNCTION portal_private.attempt_review_open(uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION portal_private.attempt_review_open(uuid,uuid) TO authenticated,service_role;

ALTER FUNCTION public.attempt_track(uuid) SET SCHEMA portal_private;
ALTER FUNCTION portal_private.attempt_track(uuid) SET search_path TO public,pg_temp;
CREATE FUNCTION public.attempt_track(p_attempt uuid) RETURNS text
LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO ''
AS $wrapper$ SELECT portal_private.attempt_track(p_attempt); $wrapper$;
REVOKE ALL ON FUNCTION public.attempt_track(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.attempt_track(uuid) TO service_role;
REVOKE ALL ON FUNCTION portal_private.attempt_track(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION portal_private.attempt_track(uuid) TO authenticated,service_role;

ALTER FUNCTION public.exam_assigned_to(uuid,uuid) SET SCHEMA portal_private;
ALTER FUNCTION portal_private.exam_assigned_to(uuid,uuid) SET search_path TO public,pg_temp;
CREATE FUNCTION public.exam_assigned_to(p_exam uuid, p_user uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO ''
AS $wrapper$ SELECT portal_private.exam_assigned_to(p_exam,p_user); $wrapper$;
REVOKE ALL ON FUNCTION public.exam_assigned_to(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.exam_assigned_to(uuid,uuid) TO service_role;
REVOKE ALL ON FUNCTION portal_private.exam_assigned_to(uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION portal_private.exam_assigned_to(uuid,uuid) TO authenticated,service_role;

ALTER FUNCTION public.exam_track(uuid) SET SCHEMA portal_private;
ALTER FUNCTION portal_private.exam_track(uuid) SET search_path TO public,pg_temp;
CREATE FUNCTION public.exam_track(p_exam uuid) RETURNS text
LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO ''
AS $wrapper$ SELECT portal_private.exam_track(p_exam); $wrapper$;
REVOKE ALL ON FUNCTION public.exam_track(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.exam_track(uuid) TO service_role;
REVOKE ALL ON FUNCTION portal_private.exam_track(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION portal_private.exam_track(uuid) TO authenticated,service_role;

ALTER FUNCTION public.group_track(uuid) SET SCHEMA portal_private;
ALTER FUNCTION portal_private.group_track(uuid) SET search_path TO public,pg_temp;
CREATE FUNCTION public.group_track(p_group uuid) RETURNS text
LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO ''
AS $wrapper$ SELECT portal_private.group_track(p_group); $wrapper$;
REVOKE ALL ON FUNCTION public.group_track(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.group_track(uuid) TO service_role;
REVOKE ALL ON FUNCTION portal_private.group_track(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION portal_private.group_track(uuid) TO authenticated,service_role;

ALTER FUNCTION public.in_group(uuid,uuid) SET SCHEMA portal_private;
ALTER FUNCTION portal_private.in_group(uuid,uuid) SET search_path TO public,pg_temp;
CREATE FUNCTION public.in_group(p_group uuid, p_user uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO ''
AS $wrapper$ SELECT portal_private.in_group(p_group,p_user); $wrapper$;
REVOKE ALL ON FUNCTION public.in_group(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.in_group(uuid,uuid) TO service_role;
REVOKE ALL ON FUNCTION portal_private.in_group(uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION portal_private.in_group(uuid,uuid) TO authenticated,service_role;

ALTER FUNCTION public.is_admin() SET SCHEMA portal_private;
ALTER FUNCTION portal_private.is_admin() SET search_path TO public,pg_temp;
CREATE FUNCTION public.is_admin() RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO ''
AS $wrapper$ SELECT portal_private.is_admin(); $wrapper$;
REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin() TO service_role;
REVOKE ALL ON FUNCTION portal_private.is_admin() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION portal_private.is_admin() TO authenticated,service_role;

ALTER FUNCTION public.is_enrolled(uuid,text) SET SCHEMA portal_private;
ALTER FUNCTION portal_private.is_enrolled(uuid,text) SET search_path TO public,pg_temp;
CREATE FUNCTION public.is_enrolled(p_user uuid, p_track text) RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO ''
AS $wrapper$ SELECT portal_private.is_enrolled(p_user,p_track); $wrapper$;
REVOKE ALL ON FUNCTION public.is_enrolled(uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.is_enrolled(uuid,text) TO service_role;
REVOKE ALL ON FUNCTION portal_private.is_enrolled(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION portal_private.is_enrolled(uuid,text) TO authenticated,service_role;

ALTER FUNCTION public.is_staff() SET SCHEMA portal_private;
ALTER FUNCTION portal_private.is_staff() SET search_path TO public,pg_temp;
CREATE FUNCTION public.is_staff() RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO ''
AS $wrapper$ SELECT portal_private.is_staff(); $wrapper$;
REVOKE ALL ON FUNCTION public.is_staff() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.is_staff() TO service_role;
REVOKE ALL ON FUNCTION portal_private.is_staff() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION portal_private.is_staff() TO authenticated,service_role;

ALTER FUNCTION public.question_track(uuid) SET SCHEMA portal_private;
ALTER FUNCTION portal_private.question_track(uuid) SET search_path TO public,pg_temp;
CREATE FUNCTION public.question_track(p_question uuid) RETURNS text
LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO ''
AS $wrapper$ SELECT portal_private.question_track(p_question); $wrapper$;
REVOKE ALL ON FUNCTION public.question_track(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.question_track(uuid) TO service_role;
REVOKE ALL ON FUNCTION portal_private.question_track(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION portal_private.question_track(uuid) TO authenticated,service_role;

ALTER FUNCTION public.staff_can_read_attempt(uuid) SET SCHEMA portal_private;
ALTER FUNCTION portal_private.staff_can_read_attempt(uuid) SET search_path TO public,pg_temp;
CREATE FUNCTION public.staff_can_read_attempt(p_attempt uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO ''
AS $wrapper$ SELECT portal_private.staff_can_read_attempt(p_attempt); $wrapper$;
REVOKE ALL ON FUNCTION public.staff_can_read_attempt(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.staff_can_read_attempt(uuid) TO service_role;
REVOKE ALL ON FUNCTION portal_private.staff_can_read_attempt(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION portal_private.staff_can_read_attempt(uuid) TO authenticated,service_role;

ALTER FUNCTION public.staff_can_read_student(uuid) SET SCHEMA portal_private;
ALTER FUNCTION portal_private.staff_can_read_student(uuid) SET search_path TO public,pg_temp;
CREATE FUNCTION public.staff_can_read_student(p_user uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO ''
AS $wrapper$ SELECT portal_private.staff_can_read_student(p_user); $wrapper$;
REVOKE ALL ON FUNCTION public.staff_can_read_student(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.staff_can_read_student(uuid) TO service_role;
REVOKE ALL ON FUNCTION portal_private.staff_can_read_student(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION portal_private.staff_can_read_student(uuid) TO authenticated,service_role;

ALTER FUNCTION public.staff_can_touch_track(text) SET SCHEMA portal_private;
ALTER FUNCTION portal_private.staff_can_touch_track(text) SET search_path TO public,pg_temp;
CREATE FUNCTION public.staff_can_touch_track(p_track text) RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO ''
AS $wrapper$ SELECT portal_private.staff_can_touch_track(p_track); $wrapper$;
REVOKE ALL ON FUNCTION public.staff_can_touch_track(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.staff_can_touch_track(text) TO service_role;
REVOKE ALL ON FUNCTION portal_private.staff_can_touch_track(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION portal_private.staff_can_touch_track(text) TO authenticated,service_role;

ALTER FUNCTION public.staff_diagnosis(text) SET SCHEMA portal_private;
ALTER FUNCTION portal_private.staff_diagnosis(text) SET search_path TO '';
CREATE FUNCTION public.staff_diagnosis(p_track text) RETURNS jsonb
LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO ''
AS $wrapper$ SELECT portal_private.staff_diagnosis(p_track); $wrapper$;
REVOKE ALL ON FUNCTION public.staff_diagnosis(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.staff_diagnosis(text) TO authenticated,service_role;
REVOKE ALL ON FUNCTION portal_private.staff_diagnosis(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION portal_private.staff_diagnosis(text) TO authenticated,service_role;

ALTER FUNCTION public.staff_group_exam_evidence(uuid,uuid[]) SET SCHEMA portal_private;
ALTER FUNCTION portal_private.staff_group_exam_evidence(uuid,uuid[]) SET search_path TO '';
CREATE FUNCTION public.staff_group_exam_evidence(p_exam uuid, p_students uuid[]) RETURNS jsonb
LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO ''
AS $wrapper$ SELECT portal_private.staff_group_exam_evidence(p_exam,p_students); $wrapper$;
REVOKE ALL ON FUNCTION public.staff_group_exam_evidence(uuid,uuid[]) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.staff_group_exam_evidence(uuid,uuid[]) TO authenticated,service_role;
REVOKE ALL ON FUNCTION portal_private.staff_group_exam_evidence(uuid,uuid[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION portal_private.staff_group_exam_evidence(uuid,uuid[]) TO authenticated,service_role;

NOTIFY pgrst,'reload schema';

