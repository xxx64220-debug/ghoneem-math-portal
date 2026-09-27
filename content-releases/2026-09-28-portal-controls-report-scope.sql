begin;
create index if not exists daily_reset_archive_track_idx on public.daily_reset_archive(track_id);
create or replace function public.portal_manage(p_actor uuid,p_action text,p_data jsonb default '{}')
returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
declare role_ text; track_ text:=p_data->>'track'; id_ uuid; ids_ uuid[]; c public.portal_track_controls%rowtype; data_ jsonb; n int; student_ uuid; mode_ text; day_ date; before_ jsonb; report_ public.portal_reports%rowtype;
begin
 select role into role_ from public.profiles where id=p_actor and status='active';
 if role_ is null or role_ not in ('admin','instructor') then raise exception 'staff_required';end if;
 if track_ is null or not exists(select 1 from public.tracks where id=track_ and is_active) then raise exception 'choose_track';end if;
 if role_='instructor' and not exists(select 1 from public.instructor_tracks where user_id=p_actor and track_id=track_) then raise exception 'forbidden_track';end if;
 select * into c from public.portal_track_controls where track_id=track_;
 if p_action='revision.list' then
  select coalesce(jsonb_agg(jsonb_build_object('id',r.question_id,'lesson',r.lesson,'idea',r.idea,'difficulty',r.difficulty,'active',r.active,'source',coalesce(q.assets->>'source_code',q.assets->>'code',''),'stem',q.stem,'ready',r.fingerprint=md5(jsonb_build_array(q.stem,q.choices,q.assets,k.correct,k.explanation)::text) and nullif(q.assets->>'release_hold_reason','') is null) order by r.lesson,r.idea,r.question_id),'[]') into data_
  from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id where q.track_id=track_;
  return jsonb_build_object('visible',c.revision_visible,'items',data_);
 elsif p_action='quiz.list' then
  return jsonb_build_object('settings',to_jsonb(c),'today_frozen',exists(select 1 from public.daily_progress where track_id=track_ and day=(now() at time zone 'Africa/Cairo')::date),
   'today',(select jsonb_build_object('day',day,'question_ids',question_ids) from public.daily_quizzes where track_id=track_ and day=(now() at time zone 'Africa/Cairo')::date),
   'questions',(select coalesce(jsonb_agg(jsonb_build_object('id',q.id,'lesson',q.topic,'stem',q.stem,'source',coalesce(q.assets->>'source_code',q.assets->>'code','')) order by q.topic,q.id),'[]') from public.questions q join public.question_keys k on k.question_id=q.id where q.track_id=track_ and q.type='mcq' and nullif(q.assets->>'verified_release','') is not null and nullif(q.assets->>'release_hold_reason','') is null and length(btrim(k.explanation))>0 and jsonb_array_length(q.choices)>=4 and jsonb_typeof(k.correct)='string' and exists(select 1 from jsonb_array_elements(q.choices) ch where ch->>'key'=k.correct#>>'{}')),
   'students',(select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'name',p.full_name,'completed',coalesce(d.completed,0),'points',coalesce(d.points,0)) order by p.full_name),'[]') from public.profiles p join public.enrollments e on e.user_id=p.id and e.track_id=track_ left join lateral(select count(quiz_completed_at) completed,sum(points) points from public.daily_progress dp where dp.user_id=p.id and dp.track_id=track_) d on true where p.role='student' and (role_='admin' or exists(select 1 from public.groups g join public.group_members gm on gm.group_id=g.id where gm.user_id=p.id and g.instructor_id=p_actor and g.track_id=track_))));
 elsif p_action='reports.list' then
  select coalesce(jsonb_agg(x order by x->>'created_at' desc),'[]') into data_ from (
   select to_jsonb(r)||jsonb_build_object('student',p.full_name,'question_stem',q.stem,'source',q.assets->>'source_code') x from public.portal_reports r join public.profiles p on p.id=r.user_id left join public.questions q on q.id=r.question_id
   where r.track_id=track_ and (role_='admin' or r.user_id=p_actor or exists(select 1 from public.groups g join public.group_members gm on gm.group_id=g.id where gm.user_id=r.user_id and g.instructor_id=p_actor and g.track_id=track_)) and (coalesce(p_data->>'status','all')='all' or r.status=p_data->>'status') order by r.created_at desc limit 200) z;
  return jsonb_build_object('items',data_,'open_count',(select count(*) from public.portal_reports r where r.track_id=track_ and (role_='admin' or r.user_id=p_actor or exists(select 1 from public.groups g join public.group_members gm on gm.group_id=g.id where gm.user_id=r.user_id and g.instructor_id=p_actor and g.track_id=track_)) and r.status in ('open','in_review')));
 elsif p_action='revision.visibility' then
  if jsonb_typeof(p_data->'visible') is distinct from 'boolean' then raise exception 'invalid_visibility';end if;
  update public.portal_track_controls set revision_visible=(p_data->>'visible')::boolean,updated_at=now() where track_id=track_;
  data_:=jsonb_build_object('visible',(p_data->>'visible')::boolean);
 elsif p_action='revision.release' then
  if jsonb_typeof(p_data->'active') is distinct from 'boolean' then raise exception 'invalid_release';end if;
  select array_agg(x::uuid) into ids_ from jsonb_array_elements_text(p_data->'ids') x;
  if coalesce(cardinality(ids_),0) not between 1 and 1000 or (select count(distinct x) from unnest(ids_) x)<>cardinality(ids_) then raise exception 'select_questions';end if;
  if (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where r.question_id=any(ids_) and q.track_id=track_)<>cardinality(ids_) then raise exception 'question_track_mismatch';end if;
  if (p_data->>'active')::boolean and exists(select 1 from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id where r.question_id=any(ids_) and (r.fingerprint<>md5(jsonb_build_array(q.stem,q.choices,q.assets,k.correct,k.explanation)::text) or nullif(q.assets->>'release_hold_reason','') is not null)) then raise exception 'questions_need_review';end if;
  update public.revision_items set active=(p_data->>'active')::boolean where question_id=any(ids_);
  data_:=jsonb_build_object('count',cardinality(ids_),'active',(p_data->>'active')::boolean);
 elsif p_action='quiz.save' then
  mode_:=p_data->>'mode';if mode_ is null or mode_ not in ('random','lessons','selected') then raise exception 'invalid_quiz_mode';end if;
  select coalesce(array_agg(x::uuid),'{}') into ids_ from jsonb_array_elements_text(coalesce(p_data->'ids','[]')) x;
  if cardinality(ids_)>1000 or (select count(distinct x) from unnest(ids_) x)<>cardinality(ids_) then raise exception 'invalid_question_selection';end if;
  if mode_='selected' and cardinality(ids_)<5 then raise exception 'select_at_least_five_questions';end if;
  select count(*) into n from public.questions q join public.question_keys k on k.question_id=q.id where q.track_id=track_ and q.type='mcq' and nullif(q.assets->>'verified_release','') is not null and nullif(q.assets->>'release_hold_reason','') is null and length(btrim(k.explanation))>0 and jsonb_array_length(q.choices)>=4 and jsonb_typeof(k.correct)='string' and exists(select 1 from jsonb_array_elements(q.choices) ch where ch->>'key'=k.correct#>>'{}') and (mode_='random' or (mode_='selected' and q.id=any(ids_)) or (mode_='lessons' and coalesce(p_data->'lessons','[]') ? q.topic));
  if n<5 then raise exception 'quiz_pool_needs_five_valid_questions';end if;
  if mode_='selected' and n<>cardinality(ids_) then raise exception 'selected_question_unavailable';end if;
  -- Same lock as daily_state: selecting today's questions cannot race an edit.
  perform pg_advisory_xact_lock(hashtextextended('daily:'||track_||':'||(now() at time zone 'Africa/Cairo')::date::text,0));
  update public.portal_track_controls set daily_mode=mode_,daily_question_ids=case when mode_='selected' then ids_ else '{}'::uuid[] end,daily_lessons=case when mode_='lessons' then array(select jsonb_array_elements_text(p_data->'lessons')) else '{}'::text[] end,updated_at=now() where track_id=track_;
  if not exists(select 1 from public.daily_progress where track_id=track_ and day=(now() at time zone 'Africa/Cairo')::date) then delete from public.daily_quizzes where track_id=track_ and day=(now() at time zone 'Africa/Cairo')::date;end if;
  data_:=jsonb_build_object('mode',mode_,'eligible',n,'today_frozen',exists(select 1 from public.daily_progress where track_id=track_ and day=(now() at time zone 'Africa/Cairo')::date));
 elsif p_action='quiz.reset' then
  if role_<>'admin' then raise exception 'admin_required';end if;
  if p_data->>'confirm' is distinct from 'RESET' then raise exception 'reset_confirmation_required';end if;
  student_:=(p_data->>'user_id')::uuid; mode_:=p_data->>'mode';day_:=nullif(p_data->>'day','')::date;
  if mode_ is null or mode_ not in ('quiz','all') then raise exception 'invalid_reset_mode';end if;
  if not exists(select 1 from public.enrollments e join public.profiles p on p.id=e.user_id where e.user_id=student_ and e.track_id=track_ and p.role='student') then raise exception 'student_not_enrolled';end if;
  if day_ is null and p_data->>'range' is distinct from 'all' then raise exception 'reset_date_required';end if;
  perform pg_advisory_xact_lock(hashtextextended('daily:'||track_||':'||(now() at time zone 'Africa/Cairo')::date::text,0));
  perform 1 from public.daily_progress where user_id=student_ and track_id=track_ and (day_ is null or day=day_) for update;
  select coalesce(jsonb_agg(to_jsonb(dp)),'[]') into before_ from public.daily_progress dp where user_id=student_ and track_id=track_ and (day_ is null or day=day_);
  insert into public.daily_reset_archive(actor_id,user_id,track_id,reset_mode,previous_progress) values(p_actor,student_,track_,mode_,before_) returning id into id_;
  if mode_='all' then delete from public.daily_progress where user_id=student_ and track_id=track_ and (day_ is null or day=day_);
  else update public.daily_progress set quiz_completed_at=null,quiz_score=null,answers='{}',points=0,bonus_awarded=false where user_id=student_ and track_id=track_ and (day_ is null or day=day_);end if;
  get diagnostics n=row_count;
  data_:=jsonb_build_object('count',n,'archive_id',id_);
 elsif p_action='reports.update' then
  id_:=(p_data->>'id')::uuid;
  if p_data->>'status' is null or p_data->>'status' not in ('open','in_review','resolved','dismissed') or length(coalesce(p_data->>'note',''))>2000 then raise exception 'invalid_report_status';end if;
  update public.portal_reports r set status=p_data->>'status',staff_note=coalesce(p_data->>'note',''),updated_at=now() where r.id=id_ and r.track_id=track_ and (role_='admin' or r.user_id=p_actor or exists(select 1 from public.groups g join public.group_members gm on gm.group_id=g.id where gm.user_id=r.user_id and g.instructor_id=p_actor and g.track_id=track_));
  if not found then raise exception 'report_not_found';end if;
  data_:=jsonb_build_object('id',id_,'status',p_data->>'status');
 else raise exception 'invalid_action';end if;
 insert into public.audit_log(actor_id,action,target_type,target_id,meta) values(p_actor,p_action,split_part(p_action,'.',1),coalesce(id_::text,track_),jsonb_build_object('track',track_,'result',data_));
 return data_;
end $$;
revoke all on function public.portal_manage(uuid,text,jsonb),public.portal_student_controls(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.portal_manage(uuid,text,jsonb),public.portal_student_controls(uuid,text,jsonb) to service_role;
commit;
