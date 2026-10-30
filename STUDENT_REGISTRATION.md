# Secure student registration — 30 October 2026

Students open `/register.html` from the sign-in page and choose their own username and password. **Students & subscriptions → Registration requests** lets administrators review the requested course, group note and optional phone number, approve or reject the request, choose its teaching group, and set subscription access dates. Further groups and payment records remain in the existing account/subscription manager.

## Production reconciliation

The starting hosted version was **126**, source `91f55446480e2257194f3d589d769d2bbbc5e34f`. GitHub main was `9dead876c4f7863bdec2f6079bde20c75ef80e23`. Production already had the form, approval queue, registration SQL and Edge Function version 1. Readback found 14 requests (13 approved, one pending). Earlier documentation claiming the registration tables were absent was stale.

The reported October 26 screenshot shows a prematurely terminated inline script on the instructor page. Both current sources already use a script-free print template; the live instructor sign-in page rendered correctly in Chrome. HTML-parser regressions now guard this exact failure mode and require exactly one registration module.

GitHub receives only registration files, its sign-in link, account-navigation entry, function configuration, tests and mirrored `dist` assets. Hosted production retains its current device restrictions, ACT2 material, assignments, reporting and all other changes. The existing registration schema is recorded for source parity; **do not reapply `supabase/sql/student_registration.sql` to production**.

## Corrected behavior

- Student inputs lock while a submission is pending. Repeated Enter/click submissions are ignored; timeout and network failure release the form for retry with the same opaque receipt. Course loading also has a timeout and retry.
- A POST fallback keeps credentials out of URLs if JavaScript fails. Passwords go only to Auth over HTTPS, are excluded from registration rows, audit metadata, lists and browser storage, and are cleared after success. Instructors never receive them.
- The server validates string types, names, usernames, track identifiers, password byte length, optional phone format and control characters. Auth's unique normalized email plus request/username/user constraints prevent repeated accounts for the same username. Shared names or family phone numbers are not treated as proof of identity.
- Completed retries bypass new-account rate quotas. Concurrent duplicate responses are reconciled against the request receipt. Auth outages are no longer misreported as unavailable usernames. Auth creation and SQL completion are separate operations: ambiguous failures keep the account untouched rather than risking deletion; rare unresolved partial creations require administrator investigation.
- Review dialogs lock fields, Cancel and Escape while saving. Active administrator authorization remains server-side; students and instructors cannot list/review requests or execute registration SQL directly. New accounts remain suspended without enrollment until approval. Approval is transactional and preserves its idempotent retry behavior, course/group matching, dates and unrecorded payment status.

## Verification

- Hosted source: 51 focused registration, HTML parsing, account-management, authorization, CORS and security tests passed.
- GitHub integration: 44 focused tests passed, including client state and answer-saving regressions.
- 34 isolated database checks passed, including duplicate rollback, approval/rejection, group and date validation, repeat approval, service-only access, rate limits and preservation of another student's enrollment state.
- Production build and public-asset credential scan passed (89 text assets).
- Chrome live form and instructor sign-in render correctly. Local preview returned connection refused. No physical-phone, Safari/Firefox or authenticated administrator browser test is claimed. Approval execution is covered by the isolated database and UI tests, without creating or approving production students.

No account, enrollment, membership, payment, attempt, score or question mutation is part of this correction. Only the registration Edge Function and frontend assets are deployed; no production SQL migration is needed.
