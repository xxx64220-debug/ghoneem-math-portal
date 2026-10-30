-- Authorized configuration: Alex online / EST I, every Tuesday from 3 Nov 2026.
-- Apply only after weekly_assessments.sql and its database regression pass.
begin;
set local lock_timeout='5s';
set local statement_timeout='30s';
do $$
declare g uuid; s portal_private.weekly_assessment_schedules%rowtype; j record;
 topics_ text[]:=array['Algebraic expressions and equations','Systems of equations','Linear functions and slope',
  'Inequalities and absolute value','Quadratics and polynomials','Functions and transformations','Exponents, radicals and growth'];
begin
 perform pg_advisory_xact_lock(hashtextextended('configure-alex-est1-weekly-algebra',0));
 if (select count(*) from public.groups where lower(btrim(name))='alex online' and track_id='est')<>1
 then raise exception 'alex_group_not_uniquely_verified'; end if;
 select id into g from public.groups where lower(btrim(name))='alex online' and track_id='est';
 if not exists(select 1 from public.group_members where group_id=g) then raise exception 'alex_group_empty'; end if;
 insert into portal_private.weekly_assessment_schedules(code,group_id,track_id,title,starts_on,topics,enabled)
 values('alex-est1-tuesday-algebra',g,'est','Alex EST I — Tuesday Algebra · 10Q · 20 min','2026-11-03',topics_,true)
 on conflict(code) do nothing;
 select * into s from portal_private.weekly_assessment_schedules where code='alex-est1-tuesday-algebra' for update;
 if s.group_id<>g or s.track_id<>'est' or s.timezone<>'Africa/Cairo' or s.weekday<>2
  or s.release_time<>'13:10'::time or s.session_time<>'13:30'::time or s.starts_on<>'2026-11-03'::date
  or s.question_count<>10 or s.duration_seconds<>1200 or s.topics<>topics_ or not s.enabled then
  raise exception 'existing_weekly_schedule_differs_review_required';
 end if;
 -- Five-minute retries are cheap once the run exists; availability itself is
 -- enforced by the server assignment window, independently of cron timing.
 select * into j from cron.job where jobname='portal-weekly-algebra-assessments';
 if found then
  if j.command<>'select portal_private.run_weekly_assessments();' or j.schedule<>'*/5 * * * *' or not j.active
   then raise exception 'existing_weekly_cron_differs_review_required'; end if;
 else
  perform cron.schedule('portal-weekly-algebra-assessments','*/5 * * * *','select portal_private.run_weekly_assessments();');
  insert into public.audit_log(action,target_type,target_id,meta)
  values('weekly_assessment.schedule_enabled','group',g::text,jsonb_build_object('code',s.code,'timezone',s.timezone,
   'weekday',s.weekday,'release_time',s.release_time,'session_time',s.session_time,'starts_on',s.starts_on,
   'duration_seconds',s.duration_seconds,'question_count',s.question_count));
 end if;
end $$;
select portal_private.run_weekly_assessments();
commit;
