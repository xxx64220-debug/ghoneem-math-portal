-- Backend-only weekly quizzes. Run through a reviewed production migration.
-- No public RPC, SECURITY DEFINER, score reset, or Daily Quiz writes.
create table if not exists portal_private.weekly_assessment_schedules (
 id uuid primary key default gen_random_uuid(),
 code text not null unique,
 group_id uuid not null references public.groups(id),
 track_id text not null references public.tracks(id),
 title text not null,
 timezone text not null default 'Africa/Cairo',
 weekday integer not null default 2 check (weekday between 0 and 6),
 release_time time not null default '13:10',
 session_time time not null default '13:30',
 starts_on date not null,
 ends_on date,
 question_count integer not null default 10 check (question_count between 1 and 20),
 duration_seconds integer not null default 1200 check (duration_seconds between 60 and 14400),
 topics text[] not null check (cardinality(topics)>0),
 enabled boolean not null default false,
 random_seed uuid not null default gen_random_uuid(),
 created_at timestamptz not null default now(),
 check (release_time < session_time),
 check (ends_on is null or ends_on >= starts_on),
 unique(group_id,weekday,release_time)
);
create table if not exists portal_private.weekly_assessment_runs (
 schedule_id uuid not null references portal_private.weekly_assessment_schedules(id),
 release_date date not null,
 status text not null check (status in ('ready','blocked')),
 exam_id uuid unique references public.exams(id),
 assignment_id uuid unique references public.assignments(id),
 question_ids uuid[] not null default '{}',
 selection jsonb not null default '[]',
 detail text,
 created_at timestamptz not null default now(),
 checked_at timestamptz not null default now(),
 primary key(schedule_id,release_date),
 check ((status='ready' and exam_id is not null and assignment_id is not null)
     or (status='blocked' and exam_id is null and assignment_id is null))
);
alter table portal_private.weekly_assessment_schedules enable row level security;
alter table portal_private.weekly_assessment_runs enable row level security;
revoke all on portal_private.weekly_assessment_schedules,portal_private.weekly_assessment_runs from public,anon,authenticated,service_role;

create or replace function portal_private.weekly_stem_key(p_stem text)
returns text language sql immutable security invoker set search_path=pg_catalog as $$
 select md5(regexp_replace(regexp_replace(lower(coalesce(p_stem,'')),
   '^(question|q)[[:space:]]*[0-9]+[.:)]?[[:space:]]*','','i'),'[[:space:]]+','','g'))
$$;
create or replace function portal_private.weekly_family_key(p_stem text,p_assets jsonb)
returns text language sql immutable security invoker set search_path=pg_catalog as $$
 select coalesce(nullif(p_assets->>'similarity_family',''),
   md5(regexp_replace(regexp_replace(lower(coalesce(p_stem,'')),
   '^(question|q)[[:space:]]*[0-9]+[.:)]?[[:space:]]*','','i'),'[0-9]+([.][0-9]+)?|[[:space:]]+','#','g')))
$$;

create or replace function portal_private.weekly_assessment_candidates(p_schedule uuid)
returns table(question_id uuid,topic text,concept text,difficulty text,stem_key text,family_key text,
 previously_assigned boolean,concept_uses bigint,topic_last_used date)
language sql stable security invoker set search_path=pg_catalog,public,portal_private as $$
 with s as materialized (select * from portal_private.weekly_assessment_schedules where id=p_schedule),
 members as materialized (select user_id from public.group_members where group_id=(select group_id from s)),
 assigned as materialized (
   select distinct unnest(e.question_ids) id from public.exams e join public.assignments a on a.exam_id=e.id
   where a.group_id=(select group_id from s) or a.user_id in (select user_id from members)
    or a.group_id in (select gm.group_id from public.group_members gm join members m using(user_id))
 ),
 attempted as materialized (
   select distinct unnest(e.question_ids) id from public.attempts a join public.exams e on e.id=a.exam_id
   where a.user_id in(select user_id from members)
   union select unnest(d.question_ids) from public.daily_group_quizzes d
    join public.daily_progress p on p.quiz_group_id=d.group_id and p.day=d.day
    where p.user_id in(select user_id from members) and p.quiz_completed_at is not null
   union select unnest(d.question_ids) from public.daily_quizzes d
    join public.daily_progress p on p.track_id=d.track_id and p.day=d.day and p.quiz_group_id is null
    where p.user_id in(select user_id from members) and p.quiz_completed_at is not null
 ),
 prior as materialized (
   select r.release_date,j.item from portal_private.weekly_assessment_runs r
   cross join lateral jsonb_array_elements(r.selection) j(item)
   where r.schedule_id=p_schedule and r.status='ready'
 ),
 used as materialized (
   select a.id,portal_private.weekly_stem_key(q.stem) stem_key from attempted a join public.questions q on q.id=a.id
   union select (item->>'id')::uuid,item->>'stem_key' from prior
 ),
 pool as materialized (
   select q.id,q.topic,lower(q.topic||' / '||coalesce(nullif(q.assets->>'lesson_subtopic',''),nullif(q.assets->>'subtopic',''),q.topic)) concept,
     q.difficulty,portal_private.weekly_stem_key(q.stem) stem_key,portal_private.weekly_family_key(q.stem,q.assets) family_key
   from s join public.questions q on q.track_id=s.track_id join public.question_keys k on k.question_id=q.id
   left join public.question_catalogue c on c.question_id=q.id
   where q.topic=any(s.topics) and q.difficulty in ('easy','medium') and not coalesce(c.reserve,false)
    and portal_private.question_eligible(q,k,s.track_id,true)
    and nullif(q.assets->>'duplicate_of','') is null
    and (q.assets->>'answer_review_status'='independently_solved'
      or concat(q.assets->>'answer_review',' ',q.assets->>'verified_release') ~* 'independent.*(solution|algebra|arithmetic|current-stem|image-check|paper-review)')
 )
 select p.id,p.topic,p.concept,p.difficulty,p.stem_key,p.family_key,
   exists(select 1 from assigned a where a.id=p.id),
   (select count(*) from prior where item->>'concept'=p.concept),
   (select max(release_date) from prior where item->>'topic'=p.topic)
 from pool p where not exists(select 1 from used u where u.id=p.id or u.stem_key=p.stem_key)
  and not exists(select 1 from prior where item->>'family_key'=p.family_key
    and release_date>=(select max(release_date)-21 from prior))
$$;

create or replace function portal_private.prepare_weekly_assessment(p_schedule uuid,p_date date)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public,portal_private as $$
declare
 s portal_private.weekly_assessment_schedules%rowtype;
 r portal_private.weekly_assessment_runs%rowtype;
 pool jsonb; chosen jsonb:='[]'; q jsonb;
 ids uuid[]:='{}'; concepts text[]:='{}'; stems text[]:='{}'; families text[]:='{}';
 topic_counts jsonb:='{}'; ex uuid; ass uuid; opens timestamptz; closes timestamptz; label text; reason text;
begin
 -- Serialize the entire schedule: concurrent workers cannot allocate the same
 -- week OR consume the same question for two different weeks.
 select * into s from portal_private.weekly_assessment_schedules where id=p_schedule for update;
 if not found then raise exception 'weekly_schedule_not_found'; end if;
 if not s.enabled then return jsonb_build_object('status','disabled'); end if;
 if p_date is null or p_date<s.starts_on or (s.ends_on is not null and p_date>s.ends_on)
   or extract(dow from p_date)::int<>s.weekday then raise exception 'invalid_weekly_release_date'; end if;
 if not exists(select 1 from public.groups where id=s.group_id and track_id=s.track_id)
   then raise exception 'weekly_group_track_mismatch'; end if;
 opens:=(p_date+s.release_time) at time zone s.timezone;
 closes:=(p_date+s.session_time) at time zone s.timezone;
 select * into r from portal_private.weekly_assessment_runs where schedule_id=s.id and release_date=p_date;
 if found and r.status='ready' then
   -- A manual edit is reported, never silently replaced or recreated.
   if not exists(select 1 from public.exams e join public.assignments a on a.id=r.assignment_id
    where e.id=r.exam_id and a.exam_id=e.id and a.group_id=s.group_id and a.user_id is null
      and a.open_at=opens and a.close_at=closes and e.duration_seconds=s.duration_seconds
      and e.question_ids=r.question_ids and e.assessment_type='quiz' and e.is_published
      and portal_private.exam_content_ready(e.question_ids,s.track_id)) then
     return jsonb_build_object('status','needs_review','date',p_date,'exam_id',r.exam_id,'reason','existing_weekly_assessment_changed_or_held');
   end if;
   return jsonb_build_object('status','existing','date',p_date,'exam_id',r.exam_id,'assignment_id',r.assignment_id);
 end if;
 if closes<=now() then return jsonb_build_object('status','missed','date',p_date); end if;
 if opens>now()+interval '8 days' then raise exception 'weekly_release_too_far_ahead'; end if;
 if not exists(select 1 from public.group_members gm join public.profiles p on p.id=gm.user_id
   join public.enrollments en on en.user_id=p.id and en.track_id=s.track_id and en.status='active'
   where gm.group_id=s.group_id and p.role='student' and p.status='active' and public.is_enrolled(p.id,s.track_id)) then
   reason:='no_active_enrolled_group_members';
 else
   label:=s.title||' — '||to_char(p_date,'DD Mon YYYY');
   -- Detect a manually-created copy before inserting anything. The durable run
   -- key and existing exam/target unique index handle automatic retries.
   if exists(select 1 from public.exams e where e.title=label)
    or exists(select 1 from public.assignments a join public.exams e on e.id=a.exam_id
      where a.group_id=s.group_id and e.assessment_type='quiz' and a.open_at<closes
        and coalesce(a.close_at,'infinity'::timestamptz)>=opens and a.open_at>=opens-interval '1 day') then
     reason:='existing_quiz_conflicts_with_weekly_window';
   else
     select coalesce(jsonb_agg(to_jsonb(c)),'[]') into pool from portal_private.weekly_assessment_candidates(s.id) c;
     for i in 1..s.question_count loop
       select v into q from jsonb_array_elements(pool) v
       where not ((v->>'concept')=any(concepts)) and not ((v->>'stem_key')=any(stems))
        and not ((v->>'family_key')=any(families))
        and coalesce((topic_counts->>(v->>'topic'))::int,0)<2
       order by coalesce((topic_counts->>(v->>'topic'))::int,0),
        (v->>'concept_uses')::bigint,
        (v->>'topic_last_used')::date nulls first,
        (v->>'previously_assigned')::boolean,
        case when v->>'difficulty'='easy' then 0 else 1 end,
        md5(s.random_seed::text||p_date::text||(v->>'question_id'))
       limit 1;
       if q is null then exit; end if;
       ids:=array_append(ids,(q->>'question_id')::uuid);
       concepts:=array_append(concepts,q->>'concept'); stems:=array_append(stems,q->>'stem_key'); families:=array_append(families,q->>'family_key');
       topic_counts:=jsonb_set(topic_counts,array[q->>'topic'],to_jsonb(coalesce((topic_counts->>(q->>'topic'))::int,0)+1));
       chosen:=chosen||jsonb_build_array((q-'question_id')||jsonb_build_object('id',q->>'question_id'));
     end loop;
     if cardinality(ids)<>s.question_count then reason:='insufficient_distinct_verified_unattempted_algebra_questions';
     else
       -- Recheck eligibility after taking content locks. Keep keys/figures in the
       -- bank; the quiz stores IDs, preserving the original rendering and key.
       perform 1 from public.questions where id=any(ids) for share;
       perform 1 from public.question_keys where question_id=any(ids) for share;
       if not portal_private.exam_content_ready(ids,s.track_id) then raise exception 'weekly_content_changed'; end if;
       insert into public.exams(track_id,title,duration_seconds,question_ids,shuffle,review_policy,max_attempts,is_published,is_full_length,assessment_type)
       values(s.track_id,label,s.duration_seconds,ids,true,'full_review',1,true,false,'quiz') returning id into ex;
       insert into public.assignments(exam_id,group_id,open_at,close_at)
       values(ex,s.group_id,opens,closes) returning id into ass;
       insert into portal_private.weekly_assessment_runs(schedule_id,release_date,status,exam_id,assignment_id,question_ids,selection)
       values(s.id,p_date,'ready',ex,ass,ids,chosen)
       on conflict(schedule_id,release_date) do update set status='ready',exam_id=excluded.exam_id,
        assignment_id=excluded.assignment_id,question_ids=excluded.question_ids,selection=excluded.selection,detail=null,checked_at=now();
       insert into public.audit_log(action,target_type,target_id,meta)
       values('weekly_assessment.created','exam',ex::text,jsonb_build_object('schedule_id',s.id,'group_id',s.group_id,'release_date',p_date,'open_at',opens,'close_at',closes,'question_count',s.question_count));
       return jsonb_build_object('status','created','date',p_date,'exam_id',ex,'assignment_id',ass,'open_at',opens,'close_at',closes);
     end if;
   end if;
 end if;
 insert into portal_private.weekly_assessment_runs(schedule_id,release_date,status,detail)
 values(s.id,p_date,'blocked',reason) on conflict(schedule_id,release_date) do update set detail=excluded.detail,checked_at=now();
 return jsonb_build_object('status','blocked','date',p_date,'reason',reason);
end $$;

create or replace function portal_private.run_weekly_assessments()
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public,portal_private as $$
declare s record; local_now timestamp; target date; result jsonb:='[]'; item jsonb;
begin
 for s in select * from portal_private.weekly_assessment_schedules where enabled order by id loop
   local_now:=now() at time zone s.timezone;
   target:=local_now::date+((s.weekday-extract(dow from local_now)::int+7)%7);
   if target=local_now::date and local_now::time>=s.session_time then target:=target+7; end if;
   if target<s.starts_on or (s.ends_on is not null and target>s.ends_on) then continue; end if;
   begin
     item:=portal_private.prepare_weekly_assessment(s.id,target);
   exception when others then
     -- This subtransaction rolls back ALL exam/assignment writes on failure.
     item:=jsonb_build_object('status','error','reason',sqlerrm,'date',target);
   end;
   result:=result||jsonb_build_array(item||jsonb_build_object('schedule_id',s.id));
 end loop;
 return result;
end $$;
revoke all on function portal_private.weekly_stem_key(text),portal_private.weekly_family_key(text,jsonb),
 portal_private.weekly_assessment_candidates(uuid),portal_private.prepare_weekly_assessment(uuid,date),
 portal_private.run_weekly_assessments() from public,anon,authenticated,service_role;
-- Intentionally executable only by the migration owner (postgres). pg_cron
-- runs as that owner. Enabling a schedule is a separate, audited operation.
