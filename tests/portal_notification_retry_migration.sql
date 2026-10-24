-- Disposable CI database only. Exercise the upgrade, not just fresh-install SQL.
begin;
create temporary table notification_upgrade_expected as
select pg_get_functiondef('public.portal_push_claim()'::regprocedure) as definition;

-- Sentinel preferences, queue data and credentials must survive the DDL unchanged.
do $$ declare u uuid:=gen_random_uuid(); s uuid; begin
 insert into auth.users(id,email) values(u,u::text||'@upgrade.test');
 insert into public.profiles(id,role,status) values(u,'student','active');
 insert into public.portal_push_config(id,public_key,private_key,worker_secret)
 values(true,'isolated-public','isolated-private','isolated-worker');
 insert into public.portal_push_subscriptions(user_id,endpoint,p256dh,auth,origin,exams,results,reminders)
 values(u,'https://fcm.googleapis.com/fcm/send/upgrade-only','isolated-key','isolated-auth','https://math.portal.ghoneem.com',false,true,true) returning id into s;
 insert into public.portal_push_queue(subscription_id,event_key,kind,title,body,attempts)
 values(s,'test:upgrade','test','Synthetic','Synthetic',2);
end $$;
create temporary table notification_upgrade_rows as
select 'config' as name,to_jsonb(t) as value from public.portal_push_config t
union all select 'subscriptions',to_jsonb(t) from public.portal_push_subscriptions t
union all select 'queue',to_jsonb(t) from public.portal_push_queue t
union all select 'profiles',to_jsonb(t) from public.profiles t
union all select 'attempts',to_jsonb(t) from public.attempts t;

-- The legacy SQL-language definition could reclaim a crashed third attempt.
create or replace function public.portal_push_claim() returns setof public.portal_push_queue language sql security invoker set search_path=public as $$
 update portal_push_queue set status='sending',attempts=attempts+1,next_attempt=now()+interval '5 minutes'
 where id in (select id from portal_push_queue where (status='pending' or (status='sending' and next_attempt<now())) and next_attempt<=now() order by created_at for update skip locked limit 10)
 returning *;
$$;
grant execute on function public.portal_push_claim() to public,anon,authenticated;
\ir ../supabase/migrations/20261016123602_portal_push_retry_limits.sql

do $$ declare r text; table_name text; begin
 if pg_get_functiondef('public.portal_push_claim()'::regprocedure)<>(select definition from notification_upgrade_expected) then
  raise exception 'upgrade differs from fresh-install claim definition';
 end if;
 if exists(
  (select * from notification_upgrade_rows except
   (select 'config',to_jsonb(t) from public.portal_push_config t
    union all select 'subscriptions',to_jsonb(t) from public.portal_push_subscriptions t
    union all select 'queue',to_jsonb(t) from public.portal_push_queue t
    union all select 'profiles',to_jsonb(t) from public.profiles t
    union all select 'attempts',to_jsonb(t) from public.attempts t))
  union all
  ((select 'config',to_jsonb(t) from public.portal_push_config t
    union all select 'subscriptions',to_jsonb(t) from public.portal_push_subscriptions t
    union all select 'queue',to_jsonb(t) from public.portal_push_queue t
    union all select 'profiles',to_jsonb(t) from public.profiles t
    union all select 'attempts',to_jsonb(t) from public.attempts t)
   except select * from notification_upgrade_rows)
 ) then raise exception 'upgrade changed notification or student data';end if;
 foreach r in array array['anon','authenticated'] loop
  if has_function_privilege(r,'public.portal_push_claim()','execute') then raise exception 'browser may claim notifications';end if;
  foreach table_name in array array['portal_push_config','portal_push_subscriptions','portal_push_queue','portal_push_releases','portal_push_campaigns'] loop
   if has_table_privilege(r,'public.'||table_name,'select,insert,update,delete') then raise exception 'browser has notification table grants';end if;
   if not (select relrowsecurity from pg_class where oid=('public.'||table_name)::regclass) then raise exception 'notification RLS disabled';end if;
  end loop;
 end loop;
 if not has_function_privilege('service_role','public.portal_push_claim()','execute') then raise exception 'worker cannot claim';end if;
 if (select prosecdef from pg_proc where oid='public.portal_push_claim()'::regprocedure) then raise exception 'claim escalates caller privileges';end if;
end $$;
-- A crashed third attempt is terminal under the actual upgraded definition.
do $$ begin
 update public.portal_push_queue set status='sending',attempts=3,next_attempt=now()-interval '1 second'
 where event_key='test:upgrade';
 perform public.portal_push_claim();
 if not exists(select 1 from public.portal_push_queue where event_key='test:upgrade'
  and status='failed' and attempts=3 and error='retry_limit_reached') then
  raise exception 'upgraded function reclaimed a fourth attempt';
 end if;
end $$;
rollback;
