# Notification collector disk-I/O mitigation

The minute-by-minute notification collector re-evaluated assignment eligibility
for already queued/sent exams. A live read-only sample returned 2,172 existing
candidates that would all hit the queue's unique constraint.

The upgrade materializes enrolled recipients, excludes already queued events
and attempts before checking assignments, and computes the open-window check
and latest matching assignment together. New release/result/reminder inserts
also skip existing keys. `ON CONFLICT DO NOTHING` remains the concurrency guard.

No scores, question data, assignments, notification preferences, credentials,
delivery schedule, retry rules, daily reminder window or enrollment rules are
changed. All queue statuses continue to suppress duplicate events. The function
remains SECURITY INVOKER and service-role-only.

## Validation

- Live `EXPLAIN (ANALYZE, BUFFERS)` of the exam SELECT on November 10:
  legacy 2,920.805 ms / 126,487 shared-buffer hits;
  candidate 107.664 ms / 19,264 hits. Both used zero physical-read and temp blocks
  in this sample. This is a query-work reduction, not proof that the provider's
  disk-I/O burst balance has recovered.
- Same-snapshot comparison found zero differences in pending event payloads.
- Local synthetic PostgreSQL tests compare complete queue outputs to the exact
  inspected production function. They cover direct/group assignments, overlap,
  future/expired/inclusive assignment boundaries, enrollment expiry, unpublished
  and inactive tracks, previous attempts, review release, multiple devices,
  opt-outs, all-status deduplication, expiry, reminder eligibility and permissions.
- Existing notification worker and SQL retry/dedup/access regressions run without
  sending notifications or accessing production accounts.

Run `npm ci --prefix tests/device-runtime --ignore-scripts --no-audit --no-fund`
then `node --test tests/portal_push_collection_performance.test.mjs tests/portal_notifications.test.cjs`.

## Deployment and rollback

The migration rejects a collector that differs from the inspected definition;
do not bypass that guard after independent changes. It only replaces one
function. Fresh-install and upgrade definitions are tested for parity.

`functions-before.json` contains the inspected definitions and existing ACLs,
not account records or credentials. If rollback is necessary, first confirm no
later changes have been made, then restore only its `portal_push_collect`
definition. Preserve the existing service-only ACL. Do not replay the complete
notification installation or reset the release/queue tables.

The Supabase provider's remaining disk-I/O budget, RAM/swap graphs and alert-time
telemetry are not exposed by the available database connector. Historical
temporary-file totals alone do not establish today's source. Avoid repeatedly
materializing all query text for diagnostics; use
`extensions.pg_stat_statements(false)` when only counters are needed.
