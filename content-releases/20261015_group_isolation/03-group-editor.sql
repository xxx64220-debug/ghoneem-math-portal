-- New group editor; installation changes no group, membership or student history.
begin;
create function portal_private.teaching_group_snapshot(p_group uuid) returns jsonb language sql stable security invoker set search_path=public,pg_temp as $$
 select jsonb_build_object('group',(select to_jsonb(g) from public.groups g where id=p_group),'members',coalesce((select jsonb_agg(user_id order by user_id) from public.group_members where group_id=p_group),'[]'::jsonb));$$;
revoke all on function portal_private.teaching_group_snapshot(uuid) from public,anon,authenticated;
create function portal_private.staff_teaching_group_state(p_group uuid) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare state_ jsonb; track_ text;
begin
 select track_id into track_ from public.groups where id=p_group;
 if track_ is null then raise exception 'group_not_found';end if;
 perform portal_private.require_course_staff(track_,p_group);
 state_:=portal_private.teaching_group_snapshot(p_group);
 return state_||jsonb_build_object('expected_hash',md5(state_::text),'is_default',p_group=public.default_group(track_));
end $$;
revoke all on function portal_private.staff_teaching_group_state(uuid) from public,anon,authenticated;
grant execute on function portal_private.staff_teaching_group_state(uuid) to authenticated,service_role;
create function portal_private.staff_save_teaching_group(p_data jsonb,p_expected_hash text) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare gid uuid; track_ text; role_ text; old_ public.groups%rowtype; state_ jsonb; members_ uuid[]; instructor_ uuid; name_ text; lessons_ text[];
begin
 if p_data is null or jsonb_typeof(p_data)<>'object' then raise exception 'invalid_group_data';end if;
 gid:=(p_data->>'id')::uuid;track_:=p_data->>'track_id';name_:=btrim(p_data->>'name');instructor_:=nullif(p_data->>'instructor_id','')::uuid;
 if gid is null or track_ is null or name_ is null or length(name_) not between 1 and 120 then raise exception 'invalid_group_data';end if;
 role_:=portal_private.require_course_staff(track_);
 perform pg_advisory_xact_lock(hashtextextended('teaching-group:'||track_||':'||lower(name_),0));
 select * into old_ from public.groups where id=gid for update;
 if found then
  if old_.track_id<>track_ then raise exception 'group_track_is_fixed';end if;
  perform portal_private.require_course_staff(track_,gid);
  if gid=public.default_group(track_) then raise exception 'default_cohort_protected';end if;
  state_:=portal_private.teaching_group_snapshot(gid);
  if p_expected_hash is null or p_expected_hash<>md5(state_::text) then raise exception 'group_changed_refresh';end if;
 elsif p_expected_hash is not null then raise exception 'group_not_found';end if;
 if exists(select 1 from public.groups g where g.track_id=track_ and g.id<>gid and lower(btrim(g.name))=lower(name_))
 or name_=(select name||' — all students' from public.tracks where id=track_) then raise exception 'group_name_already_used_in_track';end if;
 if role_='instructor' then instructor_:=auth.uid();end if;
 if instructor_ is not null and not exists(select 1 from public.profiles p join public.instructor_tracks i on i.user_id=p.id
 where p.id=instructor_ and p.role='instructor' and p.status='active' and i.track_id=track_) then raise exception 'instructor_track_mismatch';end if;
 if jsonb_typeof(p_data->'members') is distinct from 'array' or jsonb_array_length(p_data->'members')>1000
 or jsonb_typeof(p_data->'daily_lessons') is distinct from 'array' or jsonb_array_length(p_data->'daily_lessons')>10
 or length(coalesce(p_data->>'teaching_plan',''))>4000 then raise exception 'invalid_group_data';end if;
 select coalesce(array_agg(value::uuid),'{}') into members_ from jsonb_array_elements_text(p_data->'members');
 if cardinality(members_)<>(select count(distinct x) from unnest(members_) x) then raise exception 'duplicate_group_members';end if;
 if exists(select 1 from unnest(members_) uid where not exists(select 1 from public.enrollments e join public.profiles p on p.id=e.user_id
 where e.user_id=uid and e.track_id=track_ and p.role='student')) then raise exception 'group_member_course_mismatch';end if;
 select coalesce(array_agg(value),'{}') into lessons_ from jsonb_array_elements_text(p_data->'daily_lessons');
 if exists(select 1 from unnest(lessons_) lesson where not exists(select 1 from public.questions q where q.track_id=track_ and q.topic=lesson)) then raise exception 'lesson_track_mismatch';end if;
 if cardinality(lessons_)>0 and (select count(*) from public.questions q join public.question_keys k on k.question_id=q.id where q.track_id=track_ and q.topic=any(lessons_)
 and portal_private.question_eligible(q,k,track_,true) and not exists(select 1 from public.question_catalogue c where c.question_id=q.id and c.reserve))<5 then raise exception 'group_needs_five_ready_questions';end if;
 if nullif(p_data->>'course_starts_on','')::date> nullif(p_data->>'course_ends_on','')::date then raise exception 'course_end_before_start';end if;
 insert into public.groups(id,track_id,name,instructor_id,course_starts_on,course_ends_on,target_exam_date,teaching_plan,daily_lessons)
 values(gid,track_,name_,instructor_,nullif(p_data->>'course_starts_on','')::date,nullif(p_data->>'course_ends_on','')::date,
 nullif(p_data->>'target_exam_date','')::date,coalesce(p_data->>'teaching_plan',''),lessons_)
 on conflict(id) do update set name=excluded.name,instructor_id=excluded.instructor_id,course_starts_on=excluded.course_starts_on,
 course_ends_on=excluded.course_ends_on,target_exam_date=excluded.target_exam_date,teaching_plan=excluded.teaching_plan,daily_lessons=excluded.daily_lessons,plan_version=groups.plan_version+1;
 -- Membership removals are returned for separate, explicit single-student edits.
 -- Existing members stay in place until those authorized edits succeed.
 insert into public.group_members(group_id,user_id) select gid,x from unnest(members_) x on conflict do nothing;
 insert into public.audit_log(actor_id,action,target_type,target_id,meta) values(auth.uid(),'teaching_group.saved','group',gid::text,
 jsonb_build_object('before',state_,'after',portal_private.teaching_group_snapshot(gid)));
 return portal_private.staff_teaching_group_state(gid)||jsonb_build_object('remove_members',
 (select coalesce(jsonb_agg(value::uuid order by value),'[]'::jsonb) from jsonb_array_elements_text(coalesce(state_->'members','[]'::jsonb)) where not(value::uuid=any(members_))));
end $$;
revoke all on function portal_private.staff_save_teaching_group(jsonb,text) from public,anon,authenticated;
grant execute on function portal_private.staff_save_teaching_group(jsonb,text) to authenticated,service_role;
create function public.staff_teaching_group_state(p_group uuid) returns jsonb language sql security invoker set search_path=public,pg_temp as $$select portal_private.staff_teaching_group_state(p_group);$$;
create function public.staff_save_teaching_group(p_data jsonb,p_expected_hash text) returns jsonb language sql security invoker set search_path=public,pg_temp as $$select portal_private.staff_save_teaching_group(p_data,p_expected_hash);$$;
revoke all on function public.staff_teaching_group_state(uuid),public.staff_save_teaching_group(jsonb,text) from public,anon,authenticated;
grant execute on function public.staff_teaching_group_state(uuid),public.staff_save_teaching_group(jsonb,text) to authenticated,service_role;
notify pgrst,'reload schema';
commit;
