# Deployment verification — 30 October 2026

Production migration `trusted_browser_approval_and_exam_session_enforcement`
applied successfully. The first attempt had a SQL terminator packaging error and
rolled back completely; the corrected release bundle was then applied once.
Do not replay it.

The existing public Site now serves version 125, source commit
`4861af799dcff4e614fa1de77f471680aecd93f6`, deployment
`appgdep_6ae4a07e2f608191b96379a5976bed4e` (succeeded).
The browser loaded https://math.portal.ghoneem.com/ and its new device JavaScript
and CSS. The sign-in page showed no application console errors.

Edge Functions deployed successfully: `portal-devices` version 1 (gateway JWT
verification enabled), `start-attempt` version 7 and `submit-attempt` version 6
(their existing gateway settings retained; both verify identity in code).
An unauthenticated device endpoint request returned HTTP 401.

Read-only production checks confirmed:

- All 106 valid active legacy sessions passed the new approval check.
- Random unregistered sessions passed zero approval checks.
- A valid approved student session could read its own profile.
- The same student identity with an unregistered session saw zero profiles,
  attempts, and answers under the authenticated database role.
- The direct admin JSON RPC rejected an unregistered session with
  `device_approval_required` before accessing its data.
- All 46 public RLS tables have the restrictive approval policy; none are missing.
- None of the four service-only mutation RPCs grant client execution.
- The answer ownership trigger is installed.
- 119 valid legacy browser records were retained, including profiles whose
  inactive status independently denies access.

The security advisor reported no newly exposed client mutation functions. Its
private-table no-policy notices are expected: those tables deliberately deny
client access. Existing definer-helper and leaked-password-protection notices
remain outside this change.

Validation before deployment: 39 targeted tests, complete SQL bundle compilation,
production build and public credential scan passed. Browser test fixtures in the
GitHub repository now model successful device registration, and checked-in `dist`
copies match its `web` source. The Sites source uses `portal-static` instead.

Managed local browser preview could not connect. The live sign-in page was
verified, but authenticated flows on physical devices and Safari/Firefox remain
unverified. Database, Edge boundary and DOM fixtures cover approval, revocation,
session expiry, cross-account denial, exam transfer and answer preservation.

A follow-up browser recovery test passed: Request approval again ends the current
login before forgetting the approval token. A fresh sign-in remains subject to
server approval. Its publication is recorded in the pull request receipt.

Student answers, deadlines, grades and course content were not changed by rollout.
Rollback requires the recorded previous Site and Edge Functions together with
`rollback.sql`; preserve audit history and existing revocations.
