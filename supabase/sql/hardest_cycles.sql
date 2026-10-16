begin;
-- Analytics cycles never delete attempts, quiz progress, results, or answer keys.
create table public.hardest_cycles (
 id uuid primary key default gen_random_uuid(),
 track_id text not null references public.tracks(id),
 title text not null check(length(btrim(title)) between 1 and 120),
 starts_at timestamptz not null,
 ends_at timestamptz,
 created_by uuid references public.profiles(id),
 created_at timestamptz not null default now(),
 check(ends_at is null or ends_at>=starts_at)
);
create unique index hardest_one_open_cycle on public.hardest_cycles(track_id) where ends_at is null;
create index hardest_cycles_track_date on public.hardest_cycles(track_id,created_at desc);
create index hardest_cycles_creator on public.hardest_cycles(created_by);
create table public.hardest_cycle_questions (
 cycle_id uuid not null references public.hardest_cycles(id),
 question_id uuid not null,
 rank integer not null,
 track_id text not null,
 lesson text,
 stem text,
 sources text,
 answered_by integer not null,
 got_it_right integer not null,
 got_it_wrong integer not null,
 percent_correct numeric,
 question_snapshot jsonb not null,
 primary key(cycle_id,question_id)
);
alter table public.hardest_cycles enable row level security;
alter table public.hardest_cycle_questions enable row level security;
create policy hardest_cycles_read on public.hardest_cycles for select to authenticated using(public.staff_can_touch_track(track_id));
create policy hardest_cycles_insert on public.hardest_cycles for insert to authenticated with check((select public.is_admin()));
create policy hardest_cycles_update on public.hardest_cycles for update to authenticated using((select public.is_admin())) with check((select public.is_admin()));
-- Frozen whole-track archives are admin-only: instructors' live reports retain
-- their existing student/track RLS and must not acquire other students' metrics.
create policy hardest_archive_read on public.hardest_cycle_questions for select to authenticated using((select public.is_admin()));
create policy hardest_archive_insert on public.hardest_cycle_questions for insert to authenticated with check((select public.is_admin()));
revoke all on public.hardest_cycles,public.hardest_cycle_questions from public,anon,authenticated;
grant select on public.hardest_cycles to authenticated;
grant select on public.hardest_cycle_questions to authenticated;

create view public.hardest_current_questions with(security_invoker=true) as
with events as (
 select r.question_id,r.is_correct,
 case when e.assessment_type='quiz' then 'Assigned quiz' when e.assessment_type='lesson_exam' then 'Lesson exam' when e.assessment_type='full_exam' or e.is_full_length then 'Full exam' else 'Assessment' end source
 from public.attempt_results r join public.attempts a on a.id=r.attempt_id join public.exams e on e.id=a.exam_id
 where a.started_at < coalesce(nullif(current_setting('portal.hardest_cutoff',true),''),'infinity')::timestamptz
 and a.started_at>=coalesce((select c.starts_at from public.hardest_cycles c where c.track_id=e.track_id and c.ends_at is null),'-infinity'::timestamptz)
 union all
 select q.id,public.answer_matches(q.type,dp.answers->x.id,k.correct),'Daily quiz'
 from public.daily_progress dp cross join lateral jsonb_object_keys(dp.answers) x(id)
 join public.questions q on q.id=x.id::uuid join public.question_keys k on k.question_id=q.id
 where dp.quiz_completed_at is not null and dp.track_id=q.track_id
 and dp.quiz_completed_at < coalesce(nullif(current_setting('portal.hardest_cutoff',true),''),'infinity')::timestamptz
 and dp.quiz_completed_at>=coalesce((select c.starts_at from public.hardest_cycles c where c.track_id=dp.track_id and c.ends_at is null),'-infinity'::timestamptz)
), metrics as (
 select q.track_id,q.topic lesson,q.id question_id,q.stem,string_agg(distinct e.source,' + ' order by e.source) sources,
 count(*)::integer answered_by,count(*) filter(where e.is_correct)::integer got_it_right,count(*) filter(where not e.is_correct)::integer got_it_wrong,
 round(100.0*count(*) filter(where e.is_correct)/count(*),1) percent_correct
 from events e join public.questions q on q.id=e.question_id
 where (select public.is_admin()) or public.staff_can_touch_track(q.track_id)
 group by q.track_id,q.topic,q.id,q.stem
)
select row_number() over(partition by track_id order by percent_correct,answered_by desc,question_id)::integer rank,* from metrics;
create view public.hardest_archived_questions with(security_invoker=true) as
select cycle_id,rank,track_id,lesson,question_id,stem,sources,answered_by,got_it_right,got_it_wrong,percent_correct from public.hardest_cycle_questions;
revoke all on public.hardest_current_questions,public.hardest_archived_questions from public,anon;
grant select on public.hardest_current_questions,public.hardest_archived_questions to authenticated;

create schema if not exists portal_private;
grant usage on schema portal_private to authenticated;
create function portal_private.archive_hardest_cycle(p_track text,p_title text,p_expected_cycle uuid default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare old_ public.hardest_cycles%rowtype; new_ public.hardest_cycles%rowtype; n integer; boundary timestamptz; prior_cutoff text;
begin
 if auth.uid() is null or not coalesce(public.is_admin(),false) then raise exception 'admin_required'; end if;
 if length(btrim(p_title)) not between 1 and 120 or p_title is null then raise exception 'cycle_title_required'; end if;
 if not exists(select 1 from public.tracks where id=p_track) then raise exception 'invalid_track'; end if;
 perform pg_advisory_xact_lock(hashtextextended('hardest-cycle:'||p_track,0));
 select * into old_ from public.hardest_cycles where track_id=p_track and ends_at is null for update;
 if found and old_.id is distinct from p_expected_cycle then raise exception 'cycle_changed_refresh'; end if;
 if not found then
  if p_expected_cycle is not null then raise exception 'cycle_changed_refresh'; end if;
  insert into public.hardest_cycles(track_id,title,starts_at,created_by) values(p_track,btrim(p_title),'-infinity',auth.uid()) returning * into old_;
 end if;
 -- Locks serialize report rollovers. MVCC gives one consistent archive statement.
 boundary=clock_timestamp();
 prior_cutoff=current_setting('portal.hardest_cutoff',true);
 perform set_config('portal.hardest_cutoff',boundary::text,true);
 insert into public.hardest_cycle_questions(cycle_id,question_id,rank,track_id,lesson,stem,sources,answered_by,got_it_right,got_it_wrong,percent_correct,question_snapshot)
 select old_.id,r.question_id,r.rank,r.track_id,r.lesson,r.stem,r.sources,r.answered_by,r.got_it_right,r.got_it_wrong,r.percent_correct,
 jsonb_build_object('id',q.id,'track_id',q.track_id,'topic',q.topic,'type',q.type,'stem',q.stem,'choices',q.choices,'assets',q.assets)
 from public.hardest_current_questions r join public.questions q on q.id=r.question_id where r.track_id=p_track;
 get diagnostics n=row_count;
 perform set_config('portal.hardest_cutoff',coalesce(prior_cutoff,''),true);
 update public.hardest_cycles set title=btrim(p_title),ends_at=boundary where id=old_.id;
 insert into public.hardest_cycles(track_id,title,starts_at,created_by)
 values(p_track,'New cycle · '||to_char(boundary at time zone 'Africa/Cairo','DD Mon YYYY HH24:MI'),boundary,auth.uid()) returning * into new_;
 insert into public.audit_log(actor_id,action,target_type,target_id,meta) values(auth.uid(),'hardest.cycle_archived','track',p_track,jsonb_build_object('archived_cycle',old_.id,'new_cycle',new_.id,'questions',n,'boundary',boundary));
 return jsonb_build_object('archived_cycle',old_.id,'new_cycle',new_.id,'questions',n,'starts_at',boundary);
end $$;
revoke all on function portal_private.archive_hardest_cycle(text,text,uuid) from public,anon,authenticated;
grant execute on function portal_private.archive_hardest_cycle(text,text,uuid) to authenticated;
create function public.staff_archive_hardest_cycle(p_track text,p_title text,p_expected_cycle uuid default null) returns jsonb language sql security invoker set search_path=public,pg_temp as $$
 select portal_private.archive_hardest_cycle(p_track,p_title,p_expected_cycle);
$$;
revoke all on function public.staff_archive_hardest_cycle(text,text,uuid) from public,anon,authenticated;
grant execute on function public.staff_archive_hardest_cycle(text,text,uuid) to authenticated;
commit;
