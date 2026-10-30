# Device-list error correction — 30 October 2026

Opening My devices or the pending-browser approval screen returned a generic
connection error. Production reproduced PostgreSQL error 42702 because the
device-list table alias `b` conflicted with the function's PL/pgSQL record `b`.
Registration could succeed while listing failed.

The list query now uses `listed_browser`. The migration
`fix_device_list_alias_ambiguity` applied successfully in production using
`supabase/sql/device_access_list_fix.sql`. It checks the previous function
definition hash, replaces only that function, retains service-only execution,
and refuses accidental replay. The original release bundle is historical and
remains unchanged.

Nine PostgreSQL regression suites pass, including direct and post-migration
device listing for approved students, pending students, approved administrators,
and pending administrators. The new test failed with the original reported
ambiguity before the fix. Checks confirm student ownership, admin scope, secret
exclusion, and rejection of migration replay. Existing approval, revocation,
expiry, transfer, and answer-preservation checks also pass.

Read-only production verification confirms that the same student list call now
returns its own devices without tokens or session IDs. All 106 valid active
sessions remain approved, random unregistered sessions pass zero checks, all 46
protected-table policies remain, and authenticated clients still cannot execute
device mutations directly. No approved administrator session was available for
live readback; admin listing is covered by disposable database fixtures.
Security advisor findings are unchanged.

This is a database-only correction. No frontend or Edge Function redeployment
was required, and no approvals, attempts, answers, grades, or browser history
were modified. The existing dialog's Try again button reloads the fixed query.
