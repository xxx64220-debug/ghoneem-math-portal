# Browser approval and exam ownership

The portal remembers an approved browser separately from Supabase login sessions.
Students normally have two approved browsers; staff have five. Administrators can
change an account's limit from 1 to 10. Existing valid, unrevoked sessions are
grandfathered at rollout, with sufficient slots retained (up to 10). Stale device
rows without a valid Auth session do not become trusted browsers.

The first browser for an account without any browser history is approved after
authentication. Additional browsers request approval. An approved browser owner
or administrator must confirm their password and match the request code before
approving. A full account must replace an old browser or receive an administrator
limit increase. Replacing a browser that controls an unfinished exam is refused.
An explicit removal is available if access must stop immediately.

Browser tokens are random 256-bit values in local storage. Only their SHA-256
hashes are stored in the private registry. They never authenticate a user or
replace a valid Supabase session. Clearing browser storage requires approval;
IP addresses, browser versions, and fingerprint attributes are not identity
proof. This reduces casual sharing; copied credentials or intentional cooperation
cannot be completely prevented by a browser-based system.

My devices is available beside Sign out. Administrators use the Devices section
for searchable requests, per-account limits, replacements, and revocation. Each
pending browser shows a request code. The instructor should verify it with the
student before approval. Student self-approvals are limited to two per day;
new requests are limited to five per day. Requests older than seven days require
administrator review. Sign out affects only the current browser's login session.
Removed browsers can choose Request approval again. This ends the current login
and forgets only the browser approval token; the next sign-in creates a pending
request subject to the same limits and approval checks.

## Enforcement

`portal_session` requires a matching Auth session, active profile, nonrevoked
device-session row and approved browser. It no longer auto-registers arbitrary
sessions. The recovery endpoint independently verifies identity, but only allows
the caller's own registration/status and tightly scoped management actions.
Actor and session IDs come from the verified token, never the request body.

Restrictive RLS policies preserve all existing ownership, enrollment and staff
scope conditions while adding session approval. Direct JSON RPC entry points
receive the same check. Private state has RLS enabled and no client table grants.
Service-only mutation RPCs cannot be called by `anon` or `authenticated`.

Each exam attempt has one writing session. Starting/resuming an exam claims it
atomically; an answer trigger safely claims already-open pre-rollout attempts.
The attempt row lock serializes answer saves and transfers. The RLS helper is
VOLATILE so it can see the lease created by the BEFORE INSERT trigger in that
same statement. Revoked, pending, missing, expired, or signed-out sessions fail
closed. A different approved browser needs password confirmation to transfer.
Transfers have a five-minute cooldown and preserve the deadline and saved answers.
The previous browser stops saving/submitting. Old unsynced local answers are kept
separately and can be downloaded rather than replayed over transferred answers.

## Validation

Run `npm ci --prefix tests/device-runtime`, `npm ci --prefix tests/english-runtime`
and `npm ci --prefix tests/security-runtime`, then:

```
node --test tests/device-access.test.mjs tests/device-ui.test.cjs tests/device-edge.test.cjs tests/auth_security.test.cjs tests/security.test.cjs
```

These exercise real PostgreSQL rules in PGlite with disposable accounts, direct
RLS reads/writes, legacy migration, reauthentication, revocation, expiry, scope,
exam transfer/cooldown, answer/deadline preservation, hostile labels, token reuse,
and Edge Function identity handling. Existing scoring functions are unchanged.
The production build succeeds. Cloud-browser preview was unavailable because its
connection to the managed preview URL was refused. Physical-device, Safari and
Firefox behavior therefore remains unverified.

## Release and recovery

The production migration is `security-releases/20261030-device-access/apply.sql`.
It includes function-definition preconditions and both SQL files in `supabase/sql`.
Deploy the `portal-devices`, `start-attempt`, and `submit-attempt` Edge Functions
with the shared helper, then the matching Site archive to the existing domain.
Do not replay this migration after it is recorded as applied.

Rollback definitions and pre-release Edge Function source are retained in the
release directory. A rollback must pair the previous Site and Edge Functions with
`rollback.sql`. The rollback intentionally preserves device audit records and
revocations; it does not delete attempts, answers, grades or browser history.
