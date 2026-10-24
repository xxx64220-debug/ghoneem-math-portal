-- Bound crash recovery as well as ordinary provider-failure retries.
-- Already applied in production as 20261016123602 / portal_push_retry_limits.
-- Keep this ledger identity; do not replay against the existing project.
-- No subscription, preference, credential, campaign or student data is changed.
create or replace function public.portal_push_claim()
returns setof public.portal_push_queue
language plpgsql security invoker set search_path=public as $$
begin
 -- A live lease may still be delivering its third attempt. Wait for it to end.
 update portal_push_queue
 set status='failed',error=case when created_at<now()-interval '24 hours'
   then 'delivery_expired' else 'retry_limit_reached' end
 where status in ('pending','sending') and next_attempt<=now()
   and (attempts>=3 or created_at<now()-interval '24 hours');
 return query
 update portal_push_queue set status='sending',attempts=attempts+1,next_attempt=now()+interval '5 minutes'
 where id in (
  select id from portal_push_queue
  where status in ('pending','sending') and next_attempt<=now()
   and attempts<3 and created_at>=now()-interval '24 hours'
  order by created_at,id for update skip locked limit 10
 ) returning *;
end $$;
revoke all on function public.portal_push_claim() from public,anon,authenticated;
grant execute on function public.portal_push_claim() to service_role;
