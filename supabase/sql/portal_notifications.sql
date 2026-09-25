-- Isolated, service-only notification storage. No changes to exam writes.
create table public.portal_push_config (
 id boolean primary key default true check(id), public_key text not null,
 private_key text not null, worker_secret text not null
);
create table public.portal_push_subscriptions (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
 endpoint text not null unique check(length(endpoint)<1800), p256dh text not null, auth text not null,
 origin text not null, exams boolean not null default true, results boolean not null default true,
 reminders boolean not null default false, created_at timestamptz not null default now()
);
create index on public.portal_push_subscriptions(user_id);
create table public.portal_push_releases (
 exam_id uuid primary key references public.exams(id) on delete cascade, seen_at timestamptz not null default now()
);
insert into public.portal_push_releases(exam_id) select id from public.exams where is_published;
create table public.portal_push_campaigns (
 id uuid primary key, created_by uuid references public.profiles(id) on delete set null,
 title text not null, body text not null, track_id text references public.tracks(id), created_at timestamptz not null default now()
);
create table public.portal_push_queue (
 id uuid primary key default gen_random_uuid(), subscription_id uuid not null references public.portal_push_subscriptions(id) on delete cascade,
 event_key text not null, kind text not null, title text not null, body text not null,
 campaign_id uuid references public.portal_push_campaigns(id) on delete cascade,
 exam_id uuid references public.exams(id) on delete cascade,
 status text not null default 'pending' check(status in ('pending','sending','sent','failed','skipped')),
 attempts int not null default 0, next_attempt timestamptz not null default now(),
 created_at timestamptz not null default now(), sent_at timestamptz, error text,
 unique(subscription_id,event_key)
);
create index on public.portal_push_queue(status,next_attempt);
create index on public.portal_push_queue(campaign_id);
create index on public.portal_push_queue(exam_id);
create index on public.portal_push_campaigns(created_by);
do $$ declare t text; begin
 foreach t in array array['portal_push_config','portal_push_subscriptions','portal_push_releases','portal_push_campaigns','portal_push_queue'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from public, anon, authenticated',t);
 execute format('grant all on public.%I to service_role',t);
 end loop;
end $$;

-- Invoker functions: only service_role may call. No privilege escalation.
create function public.portal_push_collect() returns void language plpgsql security invoker set search_path=public as $$
begin
 insert into portal_push_releases(exam_id) select id from exams where is_published on conflict do nothing;
 insert into portal_push_queue(subscription_id,event_key,kind,title,body,exam_id)
 select s.id,'exam:'||e.id,'exam','New practice is available',left(e.title,180),e.id
 from portal_push_subscriptions s join profiles p on p.id=s.user_id and p.status='active' and p.role='student'
 join enrollments en on en.user_id=s.user_id and en.status='active'
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
end $$;
create function public.portal_push_claim() returns setof public.portal_push_queue language sql security invoker set search_path=public as $$
 update portal_push_queue set status='sending',attempts=attempts+1,next_attempt=now()+interval '5 minutes'
 where id in (select id from portal_push_queue where (status='pending' or (status='sending' and next_attempt<now())) and next_attempt<=now() order by created_at for update skip locked limit 10)
 returning *;
$$;
create function public.portal_push_announce(p_actor uuid,p_id uuid,p_title text,p_body text,p_track text default null) returns int language plpgsql security invoker set search_path=public as $$
declare n int;
begin
 if not exists(select 1 from profiles where id=p_actor and role='admin' and status='active') then raise exception 'forbidden'; end if;
 if length(trim(p_title)) not between 1 and 80 or length(trim(p_body)) not between 1 and 240 then raise exception 'invalid_message'; end if;
 if exists(select 1 from portal_push_campaigns where id=p_id) then return (select count(*) from portal_push_queue where campaign_id=p_id); end if;
 if exists(select 1 from portal_push_campaigns where created_by=p_actor and created_at>now()-interval '30 seconds') then raise exception 'Please wait 30 seconds before another announcement'; end if;
 insert into portal_push_campaigns(id,created_by,title,body,track_id) values(p_id,p_actor,p_title,p_body,p_track);
 insert into portal_push_queue(subscription_id,event_key,kind,title,body,campaign_id)
 select s.id,'announcement:'||p_id,'announcement',p_title,p_body,p_id from portal_push_subscriptions s
 join profiles p on p.id=s.user_id and p.status='active' and p.role='student'
 where exists(select 1 from enrollments e where e.user_id=s.user_id and is_enrolled(s.user_id,e.track_id) and (p_track is null or e.track_id=p_track));
 get diagnostics n=row_count; return n;
end $$;
revoke all on function public.portal_push_collect(),public.portal_push_claim(),public.portal_push_announce(uuid,uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.portal_push_collect(),public.portal_push_claim(),public.portal_push_announce(uuid,uuid,text,text,text) to service_role;
