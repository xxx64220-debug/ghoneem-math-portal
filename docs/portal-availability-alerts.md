# Portal availability issue alerts

The scheduled monitor reuses `scripts/check-portal-availability.mjs` unchanged.
It reads the public portal, Auth health endpoint and zero-row database endpoint.
It never signs in, reads student records, changes permissions or writes to Supabase.

## Alert behavior

Two probe rounds run with a 5-second pause and the existing 8-second request/body
deadline. Healthy runs now also receive a confirmation round. The same service
must fail both rounds before an incident opens. Two healthy rounds confirm recovery.
A mixed result changes no incident state. The workflow still fails if the final
probe round fails, including an unconfirmed result.

Each service has at most one unresolved incident issue. The first failure creates
an issue mentioning **@xxx64220-debug**. The body identifies the service, HTTP
status or timeout/connection error in both rounds, UTC detection times and the
exact Actions run/attempt. Repeated failures make no new issue/comment/mention.
A recovery adds one mention/comment and closes the issue. A later failure starts
a new incident. Simultaneous failures can open three issues, one per service.

State comes from bot-authored issue/comment markers, not a cache or search index.
Pagination and serialized workflow execution prevent duplicate incident creation.
A lost POST response is never retried blindly: the next run reads GitHub state.
Recovery is recorded before closure so an interrupted close can resume. A manually
closed unresolved incident is reopened without a new mention. Do not delete or
edit monitor markers: damaged/ambiguous state stops the notifier for review.
Deleting the entire incident issue loses its deduplication state.

Only allowlisted names, statuses, fixed error categories and timestamps enter
notifications. Response bodies, headers, arbitrary error text and extra report
fields do not. The alert token is the ephemeral repository `GITHUB_TOKEN`;
no PAT, mail provider, webhook secret or service-role credential is needed.

## Activation and recipient routing

The owner approved deployment and retesting on 2026-11-14. The deployed workflow
enables issue alerts unless the repository Actions variable
`PORTAL_AVAILABILITY_ALERTS_ENABLED` is exactly `false`. This records approved
activation in version control without requiring an administrative API credential.
The scripts themselves remain disabled without an explicit true environment value.
There is also a main-branch and repository guard.

The explicit recipient is the authenticated repository owner's verified GitHub
login, `xxx64220-debug`. Delivery uses GitHub @mention notifications; email
and mobile delivery follow that account's own settings. The profile email is not
proof of the notification email destination and is not configured by this patch.
The repository is public, so issues are public and existing watchers/subscribers
may also receive normal issue notifications. They cannot be excluded by @mention.

Existing native Actions notifications are separate. If enabled, they can still
report every failed run in addition to the deduplicated issue notifications.
Do not change account-wide notification settings without reviewing the effect on
other workflows. No setting or email destination has been changed by this work.

A clearly labeled synthetic bot-created test issue and recovery comment exercise
the real GitHub API, without altering production services or live incident markers.
Run the workflow manually with `delivery_test=true` when a delivery drill is needed.
An explicitly tagged deployment commit containing
`[availability-alert-delivery-test]` also requests a one-time drill on that push.
Ordinary pushes and schedules do not run the drill. The drill repeats both the
failure and recovery report to verify zero additional writes, then closes the test
issue. Test and production incident namespaces are disjoint. Offline tests do not
certify delivery; successful API calls do not prove email/mobile receipt.

## Workflow changes

- Keep the existing cron and main-branch path-filtered trigger; add an optional
  synthetic delivery drill to manual dispatch.
- Add a pull-request path-filtered job that runs offline tests with contents:read.
- Give only the trusted monitoring job contents:read and issues:write.
- Disable checkout credential persistence.
- Run offline tests before production health checks.
- Write a sanitized report to RUNNER_TEMP and a human-readable Actions summary.
- Continue after a failed probe long enough to reconcile alerts; retain a red
  final workflow result for failed health checks.
- Increase job timeout from 2 to 3 minutes to allow confirmation and issue writes.
- Keep production monitor runs serialized; PR tests have a separate concurrency
  group so they do not displace the monitor.

The notifier is skipped for cancelled/skipped checks. Missing/invalid reports,
API authorization failures and damaged state are monitoring/delivery errors,
not fabricated service outages or recoveries. They fail the job. Checkout,
runner, test or scheduling failures cannot produce service-specific issue alerts
without valid health evidence; native Actions notifications remain a fallback.

## Verification

Run from the repository root:

```sh
node --test tests/portal-availability.test.mjs
node --check scripts/run-portal-availability.mjs
node --check scripts/alert-portal-availability.mjs
git diff --check
```

The tests inject transport/state fixtures and forbid accidental network access.
No production shutdown, real incident creation, credentials or student data is
required. Pull-request tests never execute live probes or alert writes.

## Scheduling limitations and rollback

GitHub scheduled Actions are best effort. They can be delayed or dropped and
cannot alert while GitHub or the scheduler is unavailable. An issue notifier
does not repair scheduling gaps or establish a 15-minute detection guarantee.
Do not infer continuous uptime from a successful sample.

Set `PORTAL_AVAILABILITY_ALERTS_ENABLED=false` to stop issue writes while
retaining read-only probes and workflow results. Open incidents will then stop
updating until alerts are reenabled. Revert this patch to restore the original
single-round-when-healthy workflow; no database or portal rollback is needed.

References:
- https://docs.github.com/en/actions/concepts/workflows-and-actions/notifications-for-workflow-runs
- https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows
- https://docs.github.com/en/actions/tutorials/authenticate-with-github_token
- https://docs.github.com/en/rest/issues/issues
- https://docs.github.com/en/rest/issues/comments
