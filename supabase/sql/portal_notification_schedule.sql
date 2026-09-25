-- Credentials are provisioned privately in portal_push_config, never in source.
create extension if not exists pg_net with schema extensions;
select cron.schedule('portal-push-delivery','* * * * *', $job$
 select net.http_post(
  url:='https://wfhurjyouemahvkcfkdz.supabase.co/functions/v1/portal-notifications',
  headers:=jsonb_build_object('Content-Type','application/json','x-portal-worker',(select worker_secret from public.portal_push_config where id)),
  body:='{"action":"dispatch"}'::jsonb,timeout_milliseconds:=120000
 );
$job$);
