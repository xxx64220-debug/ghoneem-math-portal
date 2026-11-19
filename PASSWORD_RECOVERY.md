# Student password recovery with administrator approval

Students use **Forgot password?** on the sign-in page. They provide their existing username/email, full name, and optional group/contact details. Requests from all groups appear in **Instructor console → Password requests**, also reachable from **Students & subscriptions**. A pending count refreshes during console navigation at most once per minute, with an explicit Refresh button. No email or WhatsApp notification is sent automatically.

Administrators confirm identity using their existing student contact, then approve or reject. Approval records the decision and generates a single-use Supabase Auth recovery link for private sharing. Students open that link, enter a new password, and sign in using their existing username. The old password remains valid until the student finishes the reset. Unknown/suspended/staff accounts cannot be approved. Rejection changes no credentials.

Approved requests offer **Create new reset link** if delivery fails or the link expires. Requests/approvals older than seven days require a new request. Supabase Auth enforces the recovery-token expiry and one-time verification. Link tokens are kept only in memory and the URL fragment, stripped from the address bar on opening, and never stored in request rows, audit records or browser storage. Merely opening the page does not consume the token. Recovery uses a separate memory-only Auth client; it cannot replace an existing portal session. Passwords are sent only to Supabase Auth. Sign-out requests global refresh-session revocation after a successful change; issued access JWTs may remain valid until their normal expiry.

## Backend and rollout

- Project: `wfhurjyouemahvkcfkdz` (ghoneem hub).
- Migration: `20261119122819_student_password_recovery.sql`; applied on November 19, 2026. The local filename matches the version read back from hosted migration history. Do not reapply it manually.
- New Edge Function: `password-recovery`, version 1. Public submissions are intentional (`verify_jwt=false`); list/count/review/issue validate the administrator JWT against Auth, read the active role from profiles, and validate the current approved session through `portal_session`.
- The function has its own small auth helper because the general Site `_shared/http.ts` contains an unapplied MFA pilot. This release does not enable or change that pilot.
- RLS enabled; no anon/authenticated table grants or RPC execution. All five RPCs use SECURITY INVOKER and are executable only by service_role. No new read/write policy exposes reset requests. Security advisor reports only the two expected INFO “RLS enabled, no policy” findings for these service-only tables.
- Requests are bounded to 4 KB, paged 25 at a time, deduplicated transactionally, and limited to 10 per IP per hour / 200 globally per day. An issuance lease prevents concurrent link generation. Generic public responses do not disclose whether an account exists.
- No question-bank, score, attempt, enrollment, subscription or device-policy changes.

## Verification

- 18 focused API/auth/UI/HTML tests and 49 isolated database assertions passed, covering unauthorized review, rejection, missing/expired approval, retries, duplicate requests, concurrent issuance, changed/suspended accounts, recovery-token handling and preserving account identity.
- 28 existing registration/auth/sign-in regression tests passed on the hosted source. GitHub integration ran the recovery and existing registration/auth suites successfully.
- Production service-role submit/deduplication verified inside a transaction and rolled back; no synthetic request retained. Live anonymous list/approval rejected (401), malformed submissions rejected (400), foreign origins rejected (403). Production table/RPC ACLs read back and verified.
- Browser preview: real student form, synthetic administrator queue and identity-confirmation/approval flow, including 360px and 390px content widths. Desktop sign-in link verified. No real student's password was reset, and an authenticated production administrator-to-student reset has not been exercised.
- Production build gate passed: 5,002 assets, 64 classic scripts, 3 inline scripts, 237 local links, zero broken links. Temporary QA fixtures removed before packaging.

## Rollback

Hide/remove the sign-in recovery link and administrator module, then redeploy the prior frontend version. Leave the additive tables for audit retention. Disable the new Edge Function if required; it is not used by existing sign-in or assessment flows. Do not drop accounts, reset passwords or delete attempts as rollback.
