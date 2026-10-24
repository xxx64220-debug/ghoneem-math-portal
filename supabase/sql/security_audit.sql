-- Read-only catalog audit. No student rows, tokens, passwords, or writes.
-- Run against the intended project; automated tests use disposable databases only.
select jsonb_build_object(
 'tables_without_rls', (select coalesce(jsonb_agg(n.nspname||'.'||c.relname),'[]') from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','portal_private') and c.relkind in ('r','p') and not c.relrowsecurity),
 'public_definers_callable_by_anon', (select coalesce(jsonb_agg(p.oid::regprocedure::text),'[]') from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prosecdef and has_function_privilege('anon',p.oid,'execute')),
 'definers_without_search_path', (select coalesce(jsonb_agg(n.nspname||'.'||p.proname),'[]') from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','portal_private') and p.prosecdef and not exists(select 1 from unnest(coalesce(p.proconfig,'{}')) cfg where cfg like 'search_path=%')),
 'readable_views_without_invoker_security', (select coalesce(jsonb_agg(c.relname),'[]') from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='v' and (has_table_privilege('anon',c.oid,'select') or has_table_privilege('authenticated',c.oid,'select')) and not coalesce(c.reloptions @> array['security_invoker=true'],false)),
 'definer_authorization_using_user_metadata', (select coalesce(jsonb_agg(n.nspname||'.'||p.proname),'[]') from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','portal_private') and p.prosecdef and p.prosrc ~* '(raw_user_meta_data|user_metadata)'),
 'public_storage_buckets', (select coalesce(jsonb_agg(id),'[]') from storage.buckets where public)
) as security_audit;
