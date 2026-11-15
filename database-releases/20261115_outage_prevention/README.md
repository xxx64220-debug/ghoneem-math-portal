# November 15 database outage prevention

Applied to `wfhurjyouemahvkcfkdz` at 2026-11-15 17:56:43 UTC (19:56 Cairo), migration `20261115175643_portal_outage_prevention`. This is an incremental backend release; it does not redeploy or replace the Sites frontend.

## What changed

- Cache direct `auth.uid()` lookups with scalar SELECT InitPlans in 16 existing row-level policies. Every other predicate, role, command, helper and permissive/restrictive flag is preserved.
- Bound each of the three existing cron commands before execution: 30-second SQL limits for expired-attempt grading and weekly assessment preparation; 10 seconds for the notification enqueue command; all receive a 3-second lock timeout and 30-second idle transaction timeout. The existing one-minute / five-minute schedules and command bodies are preserved.
- Run the existing availability workflow on migration and database-release pushes, as well as its existing schedule. Preserve the previously approved recipient, two-probe confirmation, duplicate suppression and recovery handling.
- Add a focused offline CI gate for authorization equivalence, job limits, drift rejection and rollback.

The push job queues an asynchronous Edge Function HTTP request. Its SQL limit bounds enqueueing, not the entire Edge Function. The job's existing 120-second HTTP timeout is unchanged. Limits cannot repair an already unresponsive database; they contain jobs once a session starts.

## Evidence and boundaries

Auth logs showed database connection deadlines/cancellation and HTTP 500/504. All 300 failed cron starts in the inspected 24-hour window reported `job startup timeout`; the earliest was 14:36 UTC. The dashboard showed severe committed-memory pressure and sustained swap on Free/Nano. A database restart at 17:20:10 UTC restored service. Memory pressure is a leading explanation, not a proven triggering query or confirmed OOM crash. Committed memory is not the same metric as resident physical RAM.

Historical statement totals were dominated by `portal_push_collect`, but PR #55's optimization was already live. Two fresh calls averaged 236.5 ms with no physical reads or temporary writes. This release does not claim that old optimization as new or change the collector again.

Current API role limits were already 3 seconds for anonymous and 8 seconds for authenticated requests. No global connection or memory settings were changed. Current post-restart connection counts did not establish a connection storm.

## Verification

- 13 offline test results pass, including 224 before/after read combinations, allowed and rejected answer/device writes, expired attempts, browser gating, course/staff separation, policy drift, cron drift, migration parity, exact rollback and rollback drift rejection.
- Fixtures model the authorization helpers and use synthetic rows. They are not a real student sign-in or a reproduction of all production helpers. Production policy readback separately verified exact predicate equivalence except for the intended `auth.uid()` wrappers.
- Supabase performance advisor: `auth_rls_initplan` warnings fell from 16 to zero. Security findings are unchanged; health advisor is empty.
- All three scheduled jobs completed successfully with the new limits, including the natural 18:00 UTC weekly-assessment run; no post-migration job failures were observed. The 45 existing availability/alert tests also pass offline.
- Before and immediately after migration, attempts (470), answers (5,874), assignments (1,398), objectives (1,120) and weekly schedules (1) were unchanged. Full-row digests also match for attempts, answers and assignments.
- Two independent GET-only probe rounds at 17:58 UTC passed for portal, Auth and database. The database probe requests zero rows and accepts only its expected permission denial; it neither authenticates as a student nor reads student data. Probe times from this executor ranged from 3.4 to 7.1 seconds, so this is an availability result, not a latency benchmark.
- Production evidence is retained in `production-readback.json`; exact policy/job baselines are retained for review and rollback.

## Monitoring gap

The actual outage alert is [issue #64](https://github.com/xxx64220-debug/ghoneem-math-portal/issues/64), created by [run 43738600409](https://github.com/xxx64220-debug/ghoneem-math-portal/actions/runs/43738600409) at 17:00 UTC. The prior recorded scheduled run was 09:53 UTC, despite the 15-minute configuration. The check did run and post an incident; inbox/email delivery was not verified.

GitHub documents that scheduled runs can be delayed or dropped. Moving the cron minutes does not guarantee detection, and the existing schedule already avoids minute zero. Keep this monitor, but use an independent external heartbeat/uptime service for a reliable detection target. Do not depend on database-hosted cron to detect that same database's outage. No new third-party account, credential, subscription or notification recipient was introduced.

## Remaining capacity and maintenance work

Free/Nano still has up to 0.5 GB RAM. These changes reduce avoidable work; they do not add capacity or promise zero outages. For the one currently active project, Pro plus Small compute (2 GB RAM) is approximately $30/month before tax and usage overages ($25 plan + ~$15 compute - $10 credit). The other project in the organization is inactive. Billing and compute changes were not made.

The current database reports PostgreSQL 17.6.1.166. Plan a supported version upgrade separately with extension compatibility checks, backup/restore verification and a maintenance window. Do not combine an untested engine upgrade with incident recovery.

At 18:02 UTC, the refreshed dashboard still showed swap use and 1.1 GB of committed memory in its last-30-minute report. It also displayed **“Your project is about to deplete its Disk IO Budget”**, with a 6 MB/s baseline after depletion. Detailed disk charts were unavailable, so the banner establishes a capacity warning, not the exact depletion time or triggering query. This additional finding reinforces the need for resource headroom; increasing RAM can reduce swapping and improve cache headroom but does not guarantee sufficient disk throughput under every workload.

No indexes were dropped based on short post-restart statistics, no private tables were opened to silence advisor notices, no cron history or student records were deleted, and no automatic database restart loop was added.

## Rollback and release discipline

`upgrade.sql` and the recorded migration are byte-identical. The CLI-created local migration was renamed to match the authoritative applied migration ledger version. Do not replay this already-applied migration or historical support SQL.

`rollback.sql` restores the exact previous 16 policy expressions and three cron commands. It first checks every current definition and aborts atomically on drift. Run only after investigating a demonstrated regression, using the migration mechanism, and then rerun policy, advisor, row-count/digest and availability checks. A failed cron transaction rolls back database work and can retry on its existing schedule; inspect the actual failure before raising a timeout.

For any recurrence, first record Auth/DB probe results, timestamps, cron errors, connection counts, memory/swap, and bounded query deltas. Preserve evidence before an authorized restart. Do not clear sessions, reset passwords or erase attempts to handle backend unavailability.

## References

- [Supabase reports and memory metrics](https://supabase.com/docs/guides/observability/reports)
- [Supabase RLS performance guidance](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select)
- [Supabase compute sizes](https://supabase.com/docs/guides/platform/compute-and-disk)
- [Supabase compute billing](https://supabase.com/docs/guides/platform/manage-your-usage/compute)
- [GitHub schedule limitations](https://docs.github.com/en/actions/how-tos/troubleshoot-workflows)
