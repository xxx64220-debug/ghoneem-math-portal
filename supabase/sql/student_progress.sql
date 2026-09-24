-- Student progress and assessment categories. Applied as one migration.
alter table public.exams add column assessment_type text not null default 'lesson_exam' check(assessment_type in ('lesson_exam','quiz','full_exam'));
update exams set assessment_type=case when is_full_length then 'full_exam' when title ~* '(quiz|warm.up)' then 'quiz' else 'lesson_exam' end;
create or replace function portal_private.sync_assessment_type() returns trigger language plpgsql set search_path=public as $$
begin
 if TG_OP='INSERT' and new.is_full_length then new.assessment_type='full_exam';
 elsif TG_OP='UPDATE' and new.assessment_type<>old.assessment_type then new.is_full_length=(new.assessment_type='full_exam');
 elsif TG_OP='UPDATE' and new.is_full_length<>old.is_full_length then new.assessment_type=case when new.is_full_length then 'full_exam' else 'lesson_exam' end;
 end if;
 return new;
end $$;
create trigger sync_assessment_type before insert or update on exams for each row execute function portal_private.sync_assessment_type();
revoke execute on function portal_private.sync_assessment_type() from public,anon,authenticated;
create or replace function public.my_exams(p_user uuid, p_track text)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', e.id, 'title', e.title, 'assessment_type', e.assessment_type, 'duration_seconds', e.duration_seconds,
           'questions', coalesce(array_length(e.question_ids,1), 0),
           'open', public.student_assignment_for(e.id, p_user) is not null,
           'attempts', (select count(*) from public.attempts a
                         where a.user_id = p_user and a.exam_id = e.id),
           'max_attempts', 1,
           'retake_available', exists(select 1 from retake_grants g where g.user_id=p_user and g.exam_id=e.id and g.consumed_at is null and (g.expires_at is null or g.expires_at>now())),
           'last', (select jsonb_build_object('id', a.id, 'status', a.status,
                                              'score', a.score, 'total', a.total,
                                              'scaled_score', a.scaled_score)
                      from public.attempts a
                     where a.user_id = p_user and a.exam_id = e.id
                     order by a.attempt_no desc limit 1)
         ) order by e.created_at), '[]'::jsonb)
    from public.exams e
   where e.track_id = p_track
     and e.is_published
     and public.is_enrolled(p_user, p_track)
     and exists (select 1 from public.assignments a
                  where a.exam_id = e.id
                    and (a.user_id = p_user
                         or exists (select 1 from public.group_members gm
                                     where gm.group_id = a.group_id and gm.user_id = p_user)));
$$;

create or replace function public.portal_admin(p_actor uuid,p_action text,p_data jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
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
end $$;
revoke execute on function public.portal_admin(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.portal_admin(uuid,text,jsonb) to service_role;

-- Keyless, student-owned aggregates. Lesson correctness is counted only after review unlocks.
create or replace function public.student_dashboard(p_user uuid,p_track text)
returns jsonb language plpgsql stable security definer set search_path=public as $$
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
 where a.user_id=p_user and e.track_id=p_track and a.status in ('graded','expired');

 with eligible as (
  select a.* from attempts a join exams e on e.id=a.exam_id
  where a.user_id=p_user and e.track_id=p_track and a.status in ('graded','expired')
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
   and ((e.is_published and exam_assigned_to(e.id,p_user)) or exists(select 1 from attempts a where a.exam_id=e.id and a.user_id=p_user and a.status in ('graded','expired')))
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
 into summary_ from attempts a join exams e on e.id=a.exam_id where a.user_id=p_user and e.track_id=p_track and a.status in ('graded','expired');
 return jsonb_build_object('summary',summary_,'history',history_,'lessons',lessons_);
end $$;
revoke execute on function public.student_dashboard(uuid,text) from public,anon,authenticated;
grant execute on function public.student_dashboard(uuid,text) to service_role;
