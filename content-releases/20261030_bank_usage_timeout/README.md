# Bank usage timeout fix — 30 October 2026

The instructor Bank usage report hit PostgreSQL's 8-second statement timeout at 14:52 UTC on October 30. Logs identify staff_bank_operations, including question eligibility/image checks. The original report measured 884 ms with a custom plan and 3,273 ms with a forced generic plan during diagnosis; these probes did not reproduce the full timeout under the then-current load.

The replacement materializes the compact question metadata and readiness result before joining response metrics and published exposure. Large question/image records no longer travel through those joins. Function-scoped force_custom_plan specializes the query for its course, caller role, optional group, cycle, and filter, even on a pooled connection using generic plans. It restores the caller's planner setting on exit. Statement timeouts, question eligibility rules, metrics, student/test-account exclusions, authorization and the public device-session wrapper are unchanged.

## Production receipt

Applied once as Supabase migration `20261030151511_bank_usage_timeout_fix`. `apply-production.sql` is the exact applied payload and rejects a changed baseline. Do not replay the release. Only the private reporting function was replaced. No student, score, attempt, assignment, question, session, or device records were changed. The frontend bundle and domain are unchanged.

The initial larger validation transaction was not applied because its native confirmation expired. The smaller function-only migration succeeded. Twelve full production report checksums matched before and after: all five active tracks, all seven SAT filters, and SAT page 2. Checks were separate read transactions; every checksum matched.

Live public RPC measured using the authenticated database role, an existing approved session, forced generic caller planning and a three-second statement limit:

| Track | Database execution |
|---|---:|
| sat | 2089 ms |
| est | 2391 ms |
| est2 | 1395 ms |
| est_eng | 236 ms |
| act2 | 877 ms |

These timings exclude HTTP/network and browser rendering. No physical phone or live browser interaction was verified.

## Regression and recovery

Run `npm ci --prefix tests/june-review-runtime --ignore-scripts --no-audit --no-fund`, then `node tests/bank_usage_timeout_db.cjs`. The disposable fixture passes 231 gates, including 92 exact full-report comparisons for admin/two instructors, groups, cycles, empty pages and all filters, plus access/history/payment regression checks. It validates repeat improvement, held/void/removed/reserve handling, test-account exclusion, unchanged permissions/wrapper and rejection of invalid scopes and student callers. A dedicated GitHub workflow runs this test.

The live security advisor has no new findings. Existing advisories remain outside this fix. `verification.json` retains checksums and timings without student records.

`supabase/sql/bank_usage_timeout.sql` is the canonical helper; its matching migration requires the existing reporting schema, including profiles.is_test. Future replays of older portal_management/test_accounts SQL must load this helper last.

For a deliberate rollback, review the current definition, restore `before.sql`, then `ALTER FUNCTION portal_private.staff_bank_operations(text,uuid,uuid,text,integer) RESET plan_cache_mode;`. Reset the planner setting explicitly as part of rollback. Rollback reintroduces the slow query and should not be automatic.
