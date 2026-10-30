-- Keep existing role and ownership checks; add session approval at every JSON RPC entry point.
CREATE OR REPLACE FUNCTION public.admin_bank_page(p_track text, p_scope text DEFAULT 'questions'::text, p_search text DEFAULT ''::text, p_lesson text DEFAULT ''::text, p_status text DEFAULT ''::text, p_sort text DEFAULT 'priority'::text, p_page integer DEFAULT 0, p_size integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare role_ text; result_ jsonb;
begin
 perform portal_private.require_current_session();
 select role into role_ from public.profiles where id=auth.uid() and status='active';
 if auth.uid() is null or role_ is null or role_ not in ('admin','instructor') then raise exception 'forbidden'; end if;
 if nullif(p_track,'') is null then raise exception 'choose_track'; end if;
 if role_='instructor' and not exists(select 1 from public.instructor_tracks where user_id=auth.uid() and track_id=p_track) then raise exception 'forbidden_track'; end if;
 if p_scope is null or p_sort is null or p_status is null or p_scope not in ('questions','source') or p_sort not in ('priority','topic','code','type','difficulty')
  or p_status not in ('','ready','review','unclassified','pending','independently_solved','source_checked')
  or p_page is null or p_page not between 0 and 100000 or p_size is null or p_size not between 1 and 100
  or length(coalesce(p_search,''))>200 then raise exception 'invalid_bank_filter'; end if;
 with usage_ as materialized (
  select qid,count(distinct e.id)::int uses from public.exams e cross join lateral unnest(e.question_ids) qid
  where e.track_id=p_track and e.is_published group by qid
 ), bank_ as materialized (
  select q.id,q.track_id,q.topic,q.type,q.difficulty,left(q.stem,180) stem,
   coalesce(nullif(q.assets->>'source_code',''),nullif(q.assets->>'source_question_id',''),q.id::text) code,
   coalesce(q.assets->>'source_document',q.assets->>'source_file',q.assets->>'source','') source,
   coalesce(nullif(btrim(q.assets->>'lesson_subtopic'),''),q.assets->>'skill','') skill,
   coalesce(q.assets->>'release_hold_reason','') hold_reason,
   coalesce(q.assets->>'verified_release','') verified_release,
   coalesce(q.assets->>'answer_review_status','') answer_review_status,
   portal_private.question_eligible(q,k,p_track,false) ready,
   nullif(btrim(q.topic),'') is null or q.topic ilike '%classification%' or coalesce(nullif(btrim(q.assets->>'lesson_subtopic'),''),nullif(btrim(q.assets->>'skill'),'')) is null or coalesce(q.assets->>'lesson_subtopic'='Needs classification',false) unclassified,
   coalesce(u.uses,0) published_uses,
   lower(concat_ws(' ',q.id::text,q.topic,q.stem,q.assets->>'lesson_subtopic',q.assets->>'skill',q.assets->>'source_file',q.assets->>'source_code',q.assets->>'source_question_id',q.assets->>'source',q.assets->>'source_document',q.assets->>'release_hold_reason')) search_text
  from public.questions q left join public.question_keys k on k.question_id=q.id left join usage_ u on u.qid=q.id
  where q.track_id=p_track and lower(coalesce(q.assets->>'bank_removed','false'))<>'true'
 ), labelled_ as materialized (
  select b.*,case when not ready then 'review' when answer_review_status='independently_solved' then 'independently_solved'
   when verified_release<>'' then 'source_checked' else 'pending' end review_status,
   case when not ready then 1 when unclassified then 2 when answer_review_status<>'independently_solved' then 3 else 4 end priority
  from bank_ b
 ), entries_ as materialized (
  select b.id::text entry_id,b.id question_id,b.code,b.source,null::int source_page,b.topic,b.stem,b.type,b.difficulty,b.skill,
   b.ready,b.unclassified,b.hold_reason,b.review_status,b.priority,b.published_uses,b.verified_release,b.search_text,''::text duplicate_of
  from labelled_ b where p_scope='questions'
  union all
  select s.id::text,b.id,s.source_code,s.source_document,s.source_page,coalesce(b.topic,s.source_section,''),coalesce(b.stem,''),coalesce(b.type,''),coalesce(b.difficulty,''),coalesce(b.skill,''),
   coalesce(b.ready,false),coalesce(b.unclassified,true),coalesce(nullif(b.hold_reason,''),case when not coalesce(b.ready,false) then s.review_status else '' end),
   case when coalesce(b.ready,false) then b.review_status else 'review' end,
   case when not coalesce(b.ready,false) then 1 else b.priority end,coalesce(b.published_uses,0),coalesce(b.verified_release,''),
   lower(concat_ws(' ',s.id::text,s.source_code,s.source_section,s.source_document,b.search_text)),coalesce(s.duplicate_of::text,'')
  from public.est_source_review s left join labelled_ b on b.id=s.question_id where p_scope='source' and s.track_id=p_track
 ), filtered_ as materialized (
  select * from entries_ where (coalesce(p_lesson,'')='' or topic=p_lesson)
   and (coalesce(p_search,'')='' or strpos(search_text,lower(p_search))>0)
   and (p_status='' or (p_status='ready' and ready) or (p_status='unclassified' and unclassified) or review_status=p_status)
 ), page_ as (
  select * from filtered_ order by
   case when p_sort='priority' then priority end,case when p_sort='priority' then published_uses end desc,
   case when p_sort='code' then code when p_sort='type' then type when p_sort='difficulty' then difficulty else topic end,code,entry_id
  limit p_size offset p_page*p_size
 ) select jsonb_build_object('total',(select count(*) from filtered_),'page',p_page,'size',p_size,
  'items',coalesce((select jsonb_agg(to_jsonb(p)-'search_text' order by
   case when p_sort='priority' then priority end,case when p_sort='priority' then published_uses end desc,
   case when p_sort='code' then code when p_sort='type' then type when p_sort='difficulty' then difficulty else topic end,code,entry_id) from page_ p),'[]'::jsonb),
  'lessons',coalesce((select jsonb_agg(topic order by topic) from (select distinct topic from entries_ where topic<>'') l),'[]'::jsonb),
  'summary',jsonb_build_object('total',(select count(*) from entries_),'held',(select count(*) from entries_ where not ready),
   'unclassified',(select count(*) from entries_ where unclassified),'independently_solved',(select count(*) from entries_ where review_status='independently_solved')))
 into result_;
 return result_;
end $function$;

CREATE OR REPLACE FUNCTION public.staff_group_exam_evidence(p_exam uuid, p_students uuid[])
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare assessment public.exams%rowtype; students jsonb;
begin
 perform portal_private.require_current_session();
  if auth.uid() is null or not coalesce(public.is_staff(),false) then
    raise exception 'staff_required' using errcode='42501';
  end if;
  select * into assessment from public.exams
    where id=p_exam and track_id in ('sat','est','est2','est_eng','act2')
      and public.staff_can_touch_track(track_id) and assessment_type in ('full_exam','lesson_exam');
  if not found then raise exception 'exam_not_available' using errcode='42501'; end if;
  if p_students is null or cardinality(p_students)>100 then
    raise exception 'invalid_student_selection' using errcode='22023';
  end if;
  -- Reject the whole request, including nonexistent IDs, without leaking which
  -- student was outside the caller's existing track / group permissions.
  if exists(select 1 from unnest(p_students) u(id) where id is null
    or not coalesce(public.staff_can_read_student(id),false)
    or not public.is_enrolled(id,assessment.track_id)
    or not exists(select 1 from public.profiles p where p.id=u.id and p.role='student')
    or (not public.is_admin() and not exists(
      select 1 from public.group_members gm join public.groups g on g.id=gm.group_id
      where gm.user_id=u.id and g.track_id=assessment.track_id and g.instructor_id=auth.uid()))) then
    raise exception 'student_scope_denied' using errcode='42501';
  end if;

  with chosen as (select distinct u.id from unnest(p_students) u(id) join public.profiles p on p.id=u.id where not p.is_test),
  attempts as (
    select c.id as user_id, a.id, a.attempt_no, a.submitted_at,
      case when a.id is null then
        case when exists(select 1 from public.attempts pending where pending.user_id=c.id
          and pending.exam_id=p_exam and pending.status in ('submitted','graded','expired'))
          then 'ungraded' else 'missing' end
        when a.score is null then 'ungraded'
        when not exists(select 1 from public.attempt_answers aa where aa.attempt_id=a.id
          and aa.response is not null and aa.response not in ('null'::jsonb,'""'::jsonb)) then 'no_responses'
        when assessment.review_policy<>'full_review' or a.review_unlocks_at is null
          or a.review_unlocks_at>now() then 'locked' else 'available' end as state
    from chosen c left join lateral (
      select a.* from public.attempts a where a.user_id=c.id and a.exam_id=p_exam
        and a.status in ('submitted','graded','expired')
      order by a.submitted_at desc nulls last, a.attempt_no desc, a.id desc limit 1
    ) a on true
  ), lesson_counts as (
    -- DISTINCT exam IDs mirrors the student plan's seen-ID guard. Only stored
    -- boolean results count; no regrading, answer matching or timing inference.
    select a.user_id, coalesce(nullif(btrim(q.assets->>'curriculum_lesson'),''),
        nullif(btrim(q.topic),''),'Unclassified questions') as lesson,
      count(*)::int as seen, count(*) filter(where r.is_correct)::int as correct,
      count(*) filter(where not r.is_correct)::int as missed,
      count(*) filter(where not r.is_correct and
        (aa.response is null or aa.response='null'::jsonb or aa.response='""'::jsonb))::int as blank
    from attempts a
    join (select distinct unnest(assessment.question_ids) as id) ids on a.state='available'
    join public.questions q on q.id=ids.id and q.track_id=assessment.track_id
    join public.question_keys k on k.question_id=q.id
    join public.attempt_results r on r.attempt_id=a.id and r.question_id=q.id
    left join public.attempt_answers aa on aa.attempt_id=a.id and aa.question_id=q.id
    where r.is_correct is not null and portal_private.question_eligible(q,k,assessment.track_id,false)
    group by a.user_id, coalesce(nullif(btrim(q.assets->>'curriculum_lesson'),''),
        nullif(btrim(q.topic),''),'Unclassified questions')
  ), lessons as (
    select user_id, jsonb_agg(jsonb_build_object('lesson',lesson,
      'classified',lesson not in ('Unclassified questions','Mixed / untagged'),
      'seen',seen,'correct',correct,'missed',missed,'blank',blank,
      'percent',round(100.0*correct/seen)) order by missed desc,
        round(100.0*correct/seen), lesson collate "C") as rows
    from lesson_counts group by user_id
  )
  select coalesce(jsonb_agg(jsonb_build_object('user_id',a.user_id,'state',a.state,
    'attempt',case when a.id is not null then jsonb_build_object('id',a.id,
      'attempt_no',a.attempt_no,'submitted_at',a.submitted_at) else null end,
    'lessons',coalesce(l.rows,'[]'::jsonb)) order by a.user_id),'[]'::jsonb)
  into students from attempts a left join lessons l on l.user_id=a.user_id;
  return jsonb_build_object('exam_id',p_exam,'track_id',assessment.track_id,'students',students);
end $function$;

CREATE OR REPLACE FUNCTION public.staff_archive_hardest_cycle(p_track text, p_title text, p_expected_cycle uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO 'public', 'pg_temp'
AS $function$select case when portal_private.require_current_session() then (select portal_private.archive_hardest_cycle(p_track,p_title,p_expected_cycle)) else null::jsonb end;$function$;

CREATE OR REPLACE FUNCTION public.staff_save_group_plan(p_group uuid, p_data jsonb, p_expected_version bigint)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO 'public', 'pg_temp'
AS $function$select case when portal_private.require_current_session() then (select portal_private.staff_save_group_plan(p_group,p_data,p_expected_version)) else null::jsonb end;$function$;

CREATE OR REPLACE FUNCTION public.staff_question_reserve(p_question uuid, p_reserve boolean, p_reason text, p_expected_hash text)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO 'public', 'pg_temp'
AS $function$select case when portal_private.require_current_session() then (select portal_private.staff_question_reserve(p_question,p_reserve,p_reason,p_expected_hash)) else null::jsonb end;$function$;

CREATE OR REPLACE FUNCTION public.staff_bank_operations(p_track text, p_group uuid DEFAULT NULL::uuid, p_cycle uuid DEFAULT NULL::uuid, p_filter text DEFAULT 'all'::text, p_page integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO 'public', 'pg_temp'
AS $function$select case when portal_private.require_current_session() then (select portal_private.staff_bank_operations(p_track,p_group,p_cycle,p_filter,p_page)) else null::jsonb end;$function$;

CREATE OR REPLACE FUNCTION public.staff_course_lessons(p_track text)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO 'public', 'pg_temp'
AS $function$select case when portal_private.require_current_session() then (select portal_private.staff_course_lessons(p_track)) else null::jsonb end;$function$;

CREATE OR REPLACE FUNCTION public.my_course_access()
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO 'public', 'pg_temp'
AS $function$select case when portal_private.require_current_session() then (select portal_private.my_course_access()) else null::jsonb end;$function$;

CREATE OR REPLACE FUNCTION public.admin_course_enrollments(p_track text DEFAULT ''::text, p_filter text DEFAULT 'all'::text, p_search text DEFAULT ''::text, p_page integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO 'public', 'pg_temp'
AS $function$select case when portal_private.require_current_session() then (select portal_private.admin_course_enrollments(p_track,p_filter,p_search,p_page)) else null::jsonb end;$function$;

CREATE OR REPLACE FUNCTION public.admin_save_course_access(p_user uuid, p_track text, p_data jsonb, p_expected_version bigint)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO 'public', 'pg_temp'
AS $function$select case when portal_private.require_current_session() then (select portal_private.admin_save_course_access(p_user,p_track,p_data,p_expected_version)) else null::jsonb end;$function$;

CREATE OR REPLACE FUNCTION public.admin_record_course_payment(p_user uuid, p_track text, p_amount numeric, p_currency text, p_paid_on date, p_reference text, p_request uuid)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO 'public', 'pg_temp'
AS $function$select case when portal_private.require_current_session() then (select portal_private.admin_record_course_payment(p_user,p_track,p_amount,p_currency,p_paid_on,p_reference,p_request)) else null::jsonb end;$function$;

CREATE OR REPLACE FUNCTION public.staff_teaching_group_state(p_group uuid)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO 'public', 'pg_temp'
AS $function$select case when portal_private.require_current_session() then (select portal_private.staff_teaching_group_state(p_group)) else null::jsonb end;$function$;

CREATE OR REPLACE FUNCTION public.staff_save_teaching_group(p_data jsonb, p_expected_hash text)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO 'public', 'pg_temp'
AS $function$select case when portal_private.require_current_session() then (select portal_private.staff_save_teaching_group(p_data,p_expected_hash)) else null::jsonb end;$function$;

CREATE OR REPLACE FUNCTION public.staff_diagnosis(p_track text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare students jsonb;
begin
 perform portal_private.require_current_session();
 if auth.uid() is null or not coalesce(public.is_staff(),false) then raise exception 'staff_required' using errcode='42501'; end if;
 if p_track not in ('sat','est','est2','est_eng','act2') or p_track is null
  or not coalesce(public.staff_can_touch_track(p_track),false) then raise exception 'track_scope_denied' using errcode='42501'; end if;
 with roster as materialized (
  select p.* from public.profiles p join public.enrollments en on en.user_id=p.id and en.track_id=p_track
  where p.role='student' and not p.is_test and public.course_history_access(p.id,p_track)
   and public.staff_can_read_student(p.id) and (public.is_admin() or exists(
    select 1 from public.groups g join public.group_members gm on gm.group_id=g.id
    where gm.user_id=p.id and g.track_id=p_track and g.instructor_id=auth.uid()))
 ), lesson_reports as materialized (
  select b.* from portal_private.diagnosis_lessons_batch(
   (select coalesce(array_agg(id),'{}'::uuid[]) from roster),p_track) b
 )
 select coalesce(jsonb_agg(jsonb_build_object('user_id',p.id,'full_name',p.full_name,'role','student','tracks',p_track,
  'practice_open',public.is_enrolled(p.id,p_track),
  'lessons',coalesce(l.lessons,'[]'::jsonb),
  'daily_groups',portal_private.diagnosis_daily(p.id,p_track,auth.uid()),
  'latest',a.row,
  'repeat_questions',(select count(*) from public.practice_notebook n join public.questions q on q.id=n.question_id
    join public.question_keys k on k.question_id=q.id where n.user_id=p.id and n.tries>=2 and n.correct_streak<2
      and portal_private.question_eligible(q,k,p_track,false))
 ) order by p.full_name,p.id),'[]'::jsonb) into students
 from roster p left join lesson_reports l on l.user_id=p.id
 left join lateral (
  select jsonb_build_object('id',a.id,'title',e.title,'assessment_type',e.assessment_type,'attempt_no',a.attempt_no,
   'score',a.score,'total',a.total,'percent',round(100.0*a.score/nullif(a.total,0)),'time_used',a.time_used,
   'submitted_at',a.submitted_at,'answered_count',(select count(*) from public.attempt_answers aa where aa.attempt_id=a.id
    and aa.response is not null and aa.response not in ('null'::jsonb,'""'::jsonb))) as row
  from public.attempts a join public.exams e on e.id=a.exam_id
  where a.user_id=p.id and e.track_id=p_track and a.status in ('submitted','graded','expired')
  order by a.submitted_at desc nulls last,a.attempt_no desc,a.id desc limit 1
 ) a on true;
 return jsonb_build_object('track_id',p_track,'students',students);
end $function$;

CREATE OR REPLACE FUNCTION public.act2_collection_search(p_search text DEFAULT ''::text, p_category text DEFAULT ''::text, p_subject text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare result_ jsonb;
begin
 perform portal_private.require_current_session();
 if not public.act2_collection_staff() then raise exception 'forbidden'; end if;
 if length(coalesce(p_search,''))>200 then raise exception 'invalid_search'; end if;
 select coalesce(jsonb_agg(to_jsonb(r) order by r.category,r.filename),'[]'::jsonb) into result_ from (
 select d.id,d.filename,d.category,d.subject,d.notes,d.page_count,d.size_bytes,
 coalesce((select jsonb_agg((v->>'page')::int order by (v->>'page')::int)
 from jsonb_array_elements(d.page_text) v where coalesce(p_search,'')<>'' and strpos(lower(v->>'text'),lower(p_search))>0),'[]'::jsonb) matching_pages
 from public.act2_collection_documents d
 where (coalesce(p_category,'')='' or d.category=p_category) and (coalesce(p_subject,'')='' or d.subject=p_subject)
 and (coalesce(p_search,'')='' or strpos(lower(concat_ws(' ',d.filename,d.notes,d.category,d.subject)),lower(p_search))>0
 or exists(select 1 from jsonb_array_elements(d.page_text) v where strpos(lower(v->>'text'),lower(p_search))>0))
 ) r;
 return result_;
end $function$;

CREATE OR REPLACE FUNCTION public.portal_admin(p_actor uuid, p_action text, p_data jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare role_ text; track_ text; id_ uuid; q jsonb; ids uuid[]; result_ jsonb; old_ jsonb; student_ uuid; group_ uuid; exam_ uuid; n int;
begin
 select role into role_ from profiles where id=p_actor and status='active';
 if role_ is null or role_ not in ('admin','instructor') then raise exception 'forbidden'; end if;
 if p_action in ('user.update','enrollment.save','device.revoke','instructor.tracks') and role_<>'admin' then raise exception 'admin_required'; end if;
 track_=p_data->>'track_id'; id_=nullif(p_data->>'id','')::uuid;
 if p_action like 'question.%' and id_ is not null then select track_id into track_ from questions where id=id_ for update; end if;
 if p_action in ('exam.save','exam.classify') and id_ is not null then select track_id into track_ from exams where id=id_ for update; end if;
 if p_action in ('assignment.save','review.release') then select track_id into track_ from exams where id=(p_data->>'exam_id')::uuid; end if;
 if p_action='group.save' and id_ is not null then select track_id into track_ from groups where id=id_; end if;
 if p_action in ('question.save','question.import','exam.save','exam.classify','assignment.save','group.save','review.release') then
  if track_ is null or not exists(select 1 from tracks where id=track_ and is_active) then raise exception 'invalid_track'; end if;
  if role_='instructor' and not exists(select 1 from instructor_tracks where user_id=p_actor and track_id=track_) then raise exception 'forbidden_track'; end if;
 end if;
 if p_action in ('question.save','question.import') then
  if p_action='question.import' and (jsonb_typeof(p_data->'questions')<>'array' or jsonb_array_length(p_data->'questions') not between 1 and 500) then raise exception 'provide_1_to_500_questions'; end if;
  result_='[]'::jsonb;
  for q in select value from jsonb_array_elements(case when p_action='question.import' then p_data->'questions' else jsonb_build_array(p_data) end) loop
   if p_action='question.import' then id_=null; end if;
   if length(trim(coalesce(q->>'stem','')))=0 or q->>'type' not in ('mcq','grid_in') or q->>'type' is null then raise exception 'invalid_question'; end if;
   if not(q ? 'correct') or q->'correct'='null'::jsonb then raise exception 'answer_key_required'; end if;
   if coalesce(q->>'difficulty','medium') not in ('easy','medium','hard') then raise exception 'invalid_difficulty'; end if;
   if q->>'type'='mcq' then
    if jsonb_typeof(q->'choices') is distinct from 'array' or jsonb_array_length(q->'choices') not between 2 and 8 then raise exception 'invalid_choices'; end if;
    if exists(select 1 from jsonb_array_elements(q->'choices') c where coalesce(c->>'key','')='' or coalesce(c->>'text','')='') or (select count(distinct c->>'key') from jsonb_array_elements(q->'choices') c)<>jsonb_array_length(q->'choices') then raise exception 'invalid_choice_keys'; end if;
    if jsonb_typeof(q->'correct')<>'string' or not exists(select 1 from jsonb_array_elements(q->'choices') c where c->>'key'=q->>'correct') then raise exception 'correct_choice_missing'; end if;
   else
    if jsonb_typeof(q->'correct') not in ('string','array') then raise exception 'invalid_grid_in_key'; end if;
    if jsonb_typeof(q->'correct')='array' and (jsonb_array_length(q->'correct')=0 or exists(select 1 from jsonb_array_elements(q->'correct') c where jsonb_typeof(c)<>'string')) then raise exception 'invalid_grid_in_key'; end if;
   end if;
   if id_ is not null and exists(select 1 from exams e where id_=any(e.question_ids) and (e.is_published or exists(select 1 from attempts a where a.exam_id=e.id))) then raise exception 'question_in_use_create_new_version'; end if;
   id_=coalesce(id_,gen_random_uuid());
   insert into questions(id,track_id,topic,difficulty,type,stem,choices,assets) values(id_,track_,coalesce(q->>'topic',''),coalesce(q->>'difficulty','medium'),q->>'type',q->>'stem',coalesce(q->'choices','[]'),coalesce(q->'assets','{}'))
   on conflict(id) do update set topic=excluded.topic,difficulty=excluded.difficulty,type=excluded.type,stem=excluded.stem,choices=excluded.choices,assets=excluded.assets;
   insert into question_keys values(id_,q->'correct',coalesce(q->>'explanation','')) on conflict(question_id) do update set correct=excluded.correct,explanation=excluded.explanation;
   result_=result_||jsonb_build_array(id_);
  end loop;
  result_=jsonb_build_object('question_ids',result_);
 elsif p_action='exam.classify' then
  update exams set assessment_type=p_data->>'assessment_type' where id=id_;
  if not found then raise exception 'exam_not_found'; end if;
  result_=jsonb_build_object('id',id_);
 elsif p_action='exam.save' then
  if id_ is not null and (p_data-'id'-'is_published')='{}'::jsonb then
   update exams set is_published=(p_data->>'is_published')::boolean where id=id_; result_=jsonb_build_object('id',id_);
  else
   if id_ is not null and exists(select 1 from attempts where exam_id=id_) then raise exception 'exam_has_attempts_create_new_version'; end if;
   select array_agg(value::uuid) into ids from jsonb_array_elements_text(p_data->'question_ids');
   if ids is null or cardinality(ids)>200 or (select count(distinct x) from unnest(ids) x)<>cardinality(ids) then raise exception 'select_1_to_200_unique_questions'; end if;
   if (select count(*) from questions q join question_keys k on k.question_id=q.id where q.id=any(ids) and q.track_id=track_)<>cardinality(ids) then raise exception 'question_track_or_key_mismatch'; end if;
   if length(trim(coalesce(p_data->>'title','')))=0 or (p_data->>'duration_seconds')::int not between 60 and 14400 then raise exception 'invalid_title_or_duration'; end if;
   if p_data->'scoring_map' is not null and p_data->'scoring_map'<>'null'::jsonb then
    if jsonb_typeof(p_data->'scoring_map')<>'object' or exists(select 1 from generate_series(0,cardinality(ids)) x where not(p_data->'scoring_map' ? x::text) or (p_data->'scoring_map'->>x::text)!~'^\d+$') then raise exception 'scoring_map_must_cover_every_raw_score'; end if;
   end if;
   id_=coalesce(id_,gen_random_uuid());
   insert into exams(id,track_id,title,duration_seconds,question_ids,shuffle,max_attempts,is_published,is_full_length,scoring_map,review_policy,assessment_type)
   values(id_,track_,p_data->>'title',(p_data->>'duration_seconds')::int,ids,true,1,coalesce((p_data->>'is_published')::boolean,false),coalesce((p_data->>'is_full_length')::boolean,false),nullif(p_data->'scoring_map','null'),coalesce(p_data->>'review_policy','full_review'),coalesce(p_data->>'assessment_type',case when (p_data->>'is_full_length')::boolean then 'full_exam' else 'lesson_exam' end))
   on conflict(id) do update set title=excluded.title,duration_seconds=excluded.duration_seconds,question_ids=excluded.question_ids,is_published=excluded.is_published,is_full_length=excluded.is_full_length,scoring_map=excluded.scoring_map,review_policy=excluded.review_policy,assessment_type=excluded.assessment_type;
   result_=jsonb_build_object('id',id_);
  end if;
 elsif p_action='assignment.save' then
  exam_=(p_data->>'exam_id')::uuid; student_=nullif(p_data->>'user_id','')::uuid; group_=nullif(p_data->>'group_id','')::uuid;
  if (student_ is null)=(group_ is null) then raise exception 'one_assignment_target_required'; end if;
  if student_ is not null and not is_enrolled(student_,track_) then raise exception 'student_not_enrolled'; end if;
  if group_ is not null and not exists(select 1 from groups where id=group_ and track_id=track_ and (role_='admin' or instructor_id=p_actor)) then raise exception 'forbidden_group'; end if;
  if role_='instructor' and student_ is not null and not exists(select 1 from group_members gm join groups g on g.id=gm.group_id where gm.user_id=student_ and g.track_id=track_ and g.instructor_id=p_actor) then raise exception 'student_outside_your_groups'; end if;
  if (p_data->>'close_at')::timestamptz <= (p_data->>'open_at')::timestamptz then raise exception 'close_must_follow_open'; end if;
  if id_ is not null and exists(select 1 from attempts where assignment_id=id_) then raise exception 'assignment_has_attempts'; end if;
  if id_ is not null and not exists(select 1 from assignments where id=id_ and exam_id=exam_) then raise exception 'assignment_exam_mismatch'; end if;
  id_=coalesce(id_,gen_random_uuid());
  insert into assignments(id,exam_id,user_id,group_id,open_at,close_at) values(id_,exam_,student_,group_,(p_data->>'open_at')::timestamptz,(p_data->>'close_at')::timestamptz)
  on conflict(id) do update set user_id=excluded.user_id,group_id=excluded.group_id,open_at=excluded.open_at,close_at=excluded.close_at;
  result_=jsonb_build_object('id',id_);
 elsif p_action='group.save' then
  if length(trim(coalesce(p_data->>'name','')))=0 then raise exception 'group_name_required'; end if;
  if id_ is not null and role_='instructor' and not exists(select 1 from groups where id=id_ and instructor_id=p_actor) then raise exception 'forbidden_group'; end if;
  id_=coalesce(id_,gen_random_uuid());
  insert into groups(id,track_id,name,instructor_id) values(id_,track_,p_data->>'name',case when role_='instructor' then p_actor else nullif(p_data->>'instructor_id','')::uuid end)
  on conflict(id) do update set name=excluded.name,instructor_id=excluded.instructor_id;
  if p_data ? 'user_ids' then
   select coalesce(array_agg(value::uuid),'{}') into ids from jsonb_array_elements_text(p_data->'user_ids');
   if exists(select 1 from unnest(ids) u where not is_enrolled(u,track_)) then raise exception 'group_member_not_enrolled'; end if;
   delete from group_members where group_id=id_;
   insert into group_members select id_,u from unnest(ids) u on conflict do nothing;
  end if;
  result_=jsonb_build_object('id',id_);
 elsif p_action='user.update' then
  if id_=p_actor and (p_data->>'role'<>'admin' or p_data->>'status'='suspended') then raise exception 'cannot_remove_own_admin_access'; end if;
  update profiles set full_name=coalesce(p_data->>'full_name',full_name),role=coalesce(p_data->>'role',role),status=coalesce(p_data->>'status',status) where id=id_;
  if not found then raise exception 'user_not_found'; end if;
  result_=jsonb_build_object('id',id_);
 elsif p_action='instructor.tracks' then
  if not exists(select 1 from profiles where id=id_ and role='instructor') then raise exception 'instructor_required'; end if;
  delete from instructor_tracks where user_id=id_;
  insert into instructor_tracks select id_,value from jsonb_array_elements_text(p_data->'tracks');
  result_=jsonb_build_object('id',id_);
 elsif p_action='enrollment.save' then
  student_=(p_data->>'user_id')::uuid;
  if p_data->>'status'='active' then perform enrol_student(student_,track_,p_actor);
  elsif p_data->>'status'='paused' then update enrollments set status='paused' where user_id=student_ and track_id=track_;
  else raise exception 'invalid_status'; end if;
  result_=jsonb_build_object('user_id',student_);
 elsif p_action='device.revoke' then
  update portal_private.trusted_browsers set status='revoked' where id=(select browser_id from public.device_sessions where id=id_);
  update public.device_sessions set revoked_at=coalesce(revoked_at,now()) where browser_id=(select browser_id from public.device_sessions where id=id_);
  update device_sessions set revoked_at=now() where id=id_ returning user_id into student_;
  if not found then raise exception 'device_not_found'; end if;
  result_=jsonb_build_object('id',id_);
 elsif p_action='review.release' then
  exam_=(p_data->>'exam_id')::uuid;
  if exists(select 1 from assignments where exam_id=exam_ and close_at>now()) then raise exception 'assignment_window_still_open'; end if;
  update exams set review_policy='full_review' where id=exam_;
  update attempts set review_unlocks_at=now() where exam_id=exam_ and status in ('graded','expired');
  result_=jsonb_build_object('exam_id',exam_);
 else raise exception 'unknown_action';
 end if;
 insert into audit_log(actor_id,action,target_type,target_id,meta) values(p_actor,p_action,split_part(p_action,'.',1),id_::text,jsonb_build_object('track_id',track_,'result',result_));
 return result_;
end $function$;
