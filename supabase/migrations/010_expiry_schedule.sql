create extension if not exists pg_cron;
select cron.schedule('sweep-expired-attempts','* * * * *',$$select public.sweep_expired_attempts()$$);
