-- Service-only collector. Keep delivery, enrollment and assignment windows intact.
create or replace function public.portal_push_collect()
returns void language plpgsql security invoker set search_path=public as $$
begin
 insert into portal_push_releases(exam_id)
 select e.id from exams e where e.is_published
 and not exists(select 1 from portal_push_releases r where r.exam_id=e.id)
 on conflict do nothing;

 -- Materialize the small recipient set once, then exclude previously queued
 -- events before evaluating assignment eligibility. The unique constraint
 -- remains the final concurrency guard; all existing queue statuses deduplicate.
 with recipients as materialized (
  select s.id,s.user_id,s.created_at,en.track_id
  from portal_push_subscriptions s
  join profiles p on p.id=s.user_id and p.status='active' and p.role='student'
  join enrollments en on en.user_id=s.user_id
  where s.exams and public.is_enrolled(s.user_id,en.track_id)
 ), candidates as materialized (
  select s.id subscription_id,s.user_id,s.created_at,e.id exam_id,e.title,r.seen_at
  from recipients s
  join exams e on e.track_id=s.track_id and e.is_published
  join portal_push_releases r on r.exam_id=e.id
  where not exists(select 1 from portal_push_queue q
   where q.subscription_id=s.id and q.event_key='exam:'||e.id)
  and not exists(select 1 from attempts a where a.user_id=s.user_id and a.exam_id=e.id)
 )
 insert into portal_push_queue(subscription_id,event_key,kind,title,body,exam_id)
 select c.subscription_id,'exam:'||c.exam_id,'exam','New practice is available',left(c.title,180),c.exam_id
 from candidates c
 cross join lateral (
  select max(greatest(a.created_at,a.open_at)) latest_assignment,
   bool_or((a.open_at is null or now()>=a.open_at)
    and (a.close_at is null or now()<=a.close_at)) has_open_assignment
  from assignments a where a.exam_id=c.exam_id
   and (a.user_id=c.user_id or exists(select 1 from group_members gm
    where gm.group_id=a.group_id and gm.user_id=c.user_id))
 ) eligibility
 where eligibility.has_open_assignment
 and greatest(c.seen_at,coalesce(eligibility.latest_assignment,c.seen_at))>=c.created_at
 on conflict do nothing;

 insert into portal_push_queue(subscription_id,event_key,kind,title,body,exam_id)
 select s.id,'result:'||a.id,'result','Your results are ready','Open the portal to view your results.',a.exam_id
 from portal_push_subscriptions s join profiles p on p.id=s.user_id and p.status='active'
 join attempts a on a.user_id=s.user_id join exams e on e.id=a.exam_id
 where s.results and a.status='graded' and a.submitted_at>=s.created_at
 and (a.review_unlocks_at is null or a.review_unlocks_at<=now())
 and not exists(select 1 from portal_push_queue q
  where q.subscription_id=s.id and q.event_key='result:'||a.id)
 on conflict do nothing;

 -- Optional reminder: preserve the existing Cairo window and per-device key.
 if extract(hour from now() at time zone 'Africa/Cairo')=18 and extract(minute from now() at time zone 'Africa/Cairo')<10 then
 insert into portal_push_queue(subscription_id,event_key,kind,title,body)
 select s.id,'daily:'||(now() at time zone 'Africa/Cairo')::date,'reminder','Time for your daily practice','Open Ghoneem Math and complete your daily quiz.'
 from portal_push_subscriptions s join profiles p on p.id=s.user_id and p.status='active' and p.role='student'
 where s.reminders and exists(select 1 from enrollments e where e.user_id=s.user_id and is_enrolled(s.user_id,e.track_id))
 and not exists(select 1 from portal_push_queue q
  where q.subscription_id=s.id and q.event_key='daily:'||(now() at time zone 'Africa/Cairo')::date)
 on conflict do nothing;
 end if;
 update portal_push_queue set status='failed',error='delivery_expired'
 where status in ('pending','sending') and created_at<now()-interval '24 hours';
end $$;
revoke all on function public.portal_push_collect() from public,anon,authenticated;
grant execute on function public.portal_push_collect() to service_role;
