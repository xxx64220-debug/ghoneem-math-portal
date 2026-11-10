-- Use only after reviewing current state; no data or schedules are changed.
begin;
set local lock_timeout='3s';
do $guard$
begin
 if md5(pg_get_functiondef('public.portal_push_collect()'::regprocedure))<>'5ab8c424e4f9d5f9de61ab5858395181' then
  raise exception 'Collector changed after this release; do not overwrite';
 end if;
end $guard$;
CREATE OR REPLACE FUNCTION public.portal_push_collect()
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
 insert into portal_push_releases(exam_id) select id from exams where is_published on conflict do nothing;
 insert into portal_push_queue(subscription_id,event_key,kind,title,body,exam_id)
 select s.id,'exam:'||e.id,'exam','New practice is available',left(e.title,180),e.id
 from portal_push_subscriptions s join profiles p on p.id=s.user_id and p.status='active' and p.role='student'
 join enrollments en on en.user_id=s.user_id and public.is_enrolled(s.user_id,en.track_id)
 join exams e on e.track_id=en.track_id and e.is_published
 join portal_push_releases r on r.exam_id=e.id
 where s.exams and student_assignment_for(e.id,s.user_id) is not null
 and greatest(r.seen_at,coalesce((select max(greatest(a.created_at,a.open_at)) from assignments a where a.exam_id=e.id and (a.user_id=s.user_id or exists(select 1 from group_members gm where gm.group_id=a.group_id and gm.user_id=s.user_id))),r.seen_at))>=s.created_at
 and not exists(select 1 from attempts a where a.user_id=s.user_id and a.exam_id=e.id)
 on conflict do nothing;
 insert into portal_push_queue(subscription_id,event_key,kind,title,body,exam_id)
 select s.id,'result:'||a.id,'result','Your results are ready','Open the portal to view your results.',a.exam_id
 from portal_push_subscriptions s join profiles p on p.id=s.user_id and p.status='active'
 join attempts a on a.user_id=s.user_id join exams e on e.id=a.exam_id
 where s.results and a.status='graded' and a.submitted_at>=s.created_at
 and (a.review_unlocks_at is null or a.review_unlocks_at<=now())
 on conflict do nothing;
 -- Optional reminder, at 18:00 Cairo; one per device/day, never a backlog.
 if extract(hour from now() at time zone 'Africa/Cairo')=18 and extract(minute from now() at time zone 'Africa/Cairo')<10 then
 insert into portal_push_queue(subscription_id,event_key,kind,title,body)
 select s.id,'daily:'||(now() at time zone 'Africa/Cairo')::date,'reminder','Time for your daily practice','Open Ghoneem Math and complete your daily quiz.'
 from portal_push_subscriptions s join profiles p on p.id=s.user_id and p.status='active' and p.role='student'
 where s.reminders and exists(select 1 from enrollments e where e.user_id=s.user_id and is_enrolled(s.user_id,e.track_id))
 on conflict do nothing;
 end if;
 update portal_push_queue set status='failed',error='delivery_expired' where status in ('pending','sending') and created_at<now()-interval '24 hours';
end $function$;

commit;
