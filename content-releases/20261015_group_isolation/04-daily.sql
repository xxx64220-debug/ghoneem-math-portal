-- Exact-definition guard: refuse to overwrite an independently changed daily_state.
DO $$BEGIN IF md5(pg_get_functiondef('public.daily_state(uuid,text)'::regprocedure)) <> 'd0c387f847e38950fa79af0697b05d2d' THEN RAISE EXCEPTION 'daily_state_changed_review_required'; END IF; END$$;
CREATE OR REPLACE FUNCTION public.daily_state(p_user uuid, p_track text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  d date := (now() at time zone 'Africa/Cairo')::date;
  qids uuid[]; gid uuid; existing_progress boolean;
  progress_ public.daily_progress%rowtype;
  quiz_ jsonb;
  leaders_ jsonb;
  myrank_ integer;
  mytotal_ integer;
  current_ integer;
  best_ integer;
  week_ jsonb;
begin
  if not exists (
    select 1 from public.profiles p join public.enrollments e on e.user_id=p.id
    join public.tracks t on t.id=e.track_id
    where p.id=p_user and p.role='student' and p.status='active'
      and e.track_id=p_track and public.is_enrolled(p_user,p_track)
  ) then raise exception 'not_enrolled_in_track'; end if;

  perform pg_advisory_xact_lock(hashtextextended('daily-user:'||p_user::text||':'||p_track||':'||d::text,0));
  select * into progress_ from public.daily_progress where user_id=p_user and track_id=p_track and day=d;
  existing_progress:=found;
  if existing_progress then gid:=progress_.quiz_group_id;
  else
   select daily_group_id into gid from public.enrollments where user_id=p_user and track_id=p_track;
   if gid is not null then
    select g.id into gid from public.groups g join public.group_members gm on gm.group_id=g.id
    where gm.user_id=p_user and g.id=gid and g.track_id=p_track and g.id is distinct from public.default_group(p_track)
    and (g.course_starts_on is null or g.course_starts_on<=d) and (g.course_ends_on is null or g.course_ends_on>=d);
   else
    select case when count(*)=1 then (array_agg(g.id))[1] else null end into gid
    from public.groups g join public.group_members gm on gm.group_id=g.id
    where gm.user_id=p_user and g.track_id=p_track and g.id is distinct from public.default_group(p_track)
    and (g.course_starts_on is null or g.course_starts_on<=d) and (g.course_ends_on is null or g.course_ends_on>=d);
   end if;
  end if;
  perform pg_advisory_xact_lock(hashtextextended('daily:'||coalesce(gid::text,p_track)||':'||d::text,0));
  if gid is null then select question_ids into qids from public.daily_quizzes where track_id=p_track and day=d;
  else select question_ids into qids from public.daily_group_quizzes where group_id=gid and day=d;end if;
  if qids is null then
  select array(
    select q.id from public.questions q join public.question_keys k on k.question_id=q.id
    where q.track_id=p_track and q.type='mcq' and portal_private.question_eligible(q,k,p_track,true) and not exists(select 1 from public.question_catalogue c where c.question_id=q.id and c.reserve)
      and ((gid is not null and exists(select 1 from public.groups g where g.id=gid and cardinality(g.daily_lessons)>0 and q.topic=any(g.daily_lessons)))
       or ((gid is null or exists(select 1 from public.groups g where g.id=gid and cardinality(g.daily_lessons)=0))
       and exists(select 1 from public.portal_track_controls c where c.track_id=p_track and
       (c.daily_mode='random' or (c.daily_mode='lessons' and q.topic=any(c.daily_lessons)) or (c.daily_mode='selected' and q.id=any(c.daily_question_ids))))))
    order by md5(d::text || q.id::text) limit 5
  ) into qids;
  if coalesce(array_length(qids,1),0)<>5 then raise exception 'daily_questions_unavailable'; end if;
  if gid is null then insert into public.daily_quizzes(track_id,day,question_ids) values(p_track,d,qids);
  else insert into public.daily_group_quizzes(group_id,day,question_ids) values(gid,d,qids);end if;
  end if;
  if coalesce(array_length(qids,1),0)<>5 then raise exception 'daily_questions_unavailable'; end if;

  insert into public.daily_progress(user_id,track_id,day,quiz_group_id) values(p_user,p_track,d,gid)
  on conflict (user_id,track_id,day) do nothing;
  select * into progress_ from public.daily_progress
  where user_id=p_user and track_id=p_track and day=d;

  if progress_.quiz_completed_at is null and (select count(*) from public.questions q join public.question_keys k on k.question_id=q.id where q.id=any(qids) and portal_private.question_eligible(q,k,p_track,true))<>5 then raise exception 'daily_content_under_review'; end if;

  select jsonb_agg(jsonb_build_object(
    'id',q.id,'stem',q.stem,'choices',q.choices,'topic',q.topic,'assets',q.assets,
    'answer',case when progress_.quiz_completed_at is null then null else
      jsonb_build_object('correct',k.correct,'explanation',k.explanation,
        'submitted',progress_.answers->q.id::text) end
  ) order by ord.n) into quiz_
  from unnest(qids) with ordinality ord(id,n)
  join public.questions q on q.id=ord.id join public.question_keys k on k.question_id=q.id;

  with ranked as (
    select e.user_id, p.full_name,
      coalesce(sum(dp.points),0)::integer as points,
      count(dp.quiz_completed_at)::integer as completed,
      row_number() over (order by coalesce(sum(dp.points),0) desc,
        count(dp.quiz_completed_at) desc, e.user_id) as rank
    from public.enrollments e join public.profiles p on p.id=e.user_id
    left join public.daily_progress dp on dp.user_id=e.user_id and dp.track_id=e.track_id and (gid is null or dp.quiz_group_id=gid)
    where e.track_id=p_track and public.is_enrolled(e.user_id,p_track) and (gid is null or exists(select 1 from public.group_members gm where gm.group_id=gid and gm.user_id=e.user_id))
    group by e.user_id,p.full_name
  ) select coalesce(jsonb_agg(jsonb_build_object(
      'rank',rank,'name',split_part(coalesce(full_name,'Student'),' ',1)
        || case when position(' ' in btrim(coalesce(full_name,'')))>0 then ' '
          || left(reverse(split_part(reverse(btrim(full_name)),' ',1)),1) || '.' else '' end,
      'points',points,'completed',completed
    ) order by rank) filter (where rank<=10),'[]'::jsonb),
    (max(rank) filter (where user_id=p_user))::integer,
    max(points) filter (where user_id=p_user)
    into leaders_,myrank_,mytotal_ from ranked;

  with days as (
    select day, day - (row_number() over(order by day))::int as island
    from public.daily_progress where user_id=p_user and track_id=p_track
      and quiz_completed_at is not null and day<=d
  ), runs as (
    select count(*)::int as length,max(day) as last_day from days group by island
  ) select coalesce(max(length) filter(where last_day>=d-1),0),
      coalesce(max(length),0) into current_,best_ from runs;
  if progress_.quiz_completed_at is null and (select count(*) from public.questions q join public.question_keys k on k.question_id=q.id where q.id=any(qids) and portal_private.question_eligible(q,k,p_track,true))<>5 then raise exception 'daily_content_under_review'; end if;

  select jsonb_agg(jsonb_build_object('date',d-offset_,
    'completed',exists(select 1 from public.daily_progress p where p.user_id=p_user
      and p.track_id=p_track and p.day=d-offset_ and p.quiz_completed_at is not null),
    'today',offset_=0) order by offset_ desc) into week_ from generate_series(0,6) offset_;

  return jsonb_build_object('date',d,'reset_at',((d+1)::timestamp at time zone 'Africa/Cairo'),
    'server_now',now(),'streak',jsonb_build_object('current',current_,'longest',best_,'week',week_),
    'group_id',gid,'group_name',(select name from public.groups where id=gid),'selection_mode',case when gid is not null and exists(select 1 from public.groups where id=gid and cardinality(daily_lessons)>0) then 'group lessons' else (select daily_mode from public.portal_track_controls where track_id=p_track) end,'track',p_track,'quiz',quiz_,'score',progress_.quiz_score,
    'completed',progress_.quiz_completed_at is not null,
    'checklist',jsonb_build_object('quiz',progress_.quiz_completed_at is not null,
      'focus',progress_.focus_done,'review',progress_.review_done,
      'bonus',progress_.bonus_awarded),
    'points_today',progress_.points,'points_total',coalesce(mytotal_,0),
    'rank',myrank_,'leaderboard',leaders_);
end;
$function$

;
