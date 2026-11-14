> Historical test-stage record. Superseded by `PRACTICE_BUNDLES_RELEASE_2026-11-13.md` after successful live verification.

# Practice bundles — test-account stage; public release held

## Current outcome

The user authorized release after all critical tests pass. The public rollout remains disabled because the authenticated production browser test could not reach the workspace: Supabase `/auth/v1/user` returned HTTP 504 at 18:12 UTC on 13 November 2026. Two bounded database inspections also timed out. Logs showed concurrent cron startup timeouts and a slow catalog query unrelated to bundle selection; the underlying infrastructure cause has not been established. Do not infer that passing isolated tests proves the live integration works.

Site version 185 was deployed only as a test-account stage. The last successful privilege check confirmed `portal_private.practice_bundle_rollout.enabled=false`, no anonymous/authenticated RPC access, and no direct student access to snapshot keys. The main page's `data-practice-bundles-enabled` flag is false, hiding the navigation entry. The direct workspace page is enabled, but the server allows only existing `profiles.is_test=true` student accounts while the rollout is off. No live bundles were created during this browser test. Existing student scores and assignments were not edited.

The latest source adds bounded connection waits and a retry message, preventing indefinite loading while preserving local drafts. This change is saved for the next deployment. It has not yet been verified through a working production session.

## Student behavior

The workspace supports SAT Math, EST I Math, EST II Math, ACT II Math, EST English and SAT English, subject to active enrollment and eligible bank content. Students choose a main topic, lessons, 1–100 questions, and difficulty. The optional exclusion filters exact previously answered question IDs, including partial saved practice; similar ideas may still appear. Questions cannot repeat within one bundle.

Answers autosave and can be resumed. Submission requires every question to have an answer. Completed bundles retain the student's choices, accepted answers and explanations. Retakes create separate attempts. Practice results are separate from assigned exams and Daily Quiz points.

## Implementation and deployed dependencies

- `supabase/sql/practice_bundles.sql`: additive private rollout setting, bundle and snapshot tables, service-only RPCs, student/enrollment checks, held/reserved question exclusion, eligibility-cache validation, idempotent creation, serialized per-student creation, revision-controlled saving, and immutable completed results. Maximum 20 unfinished bundles per student.
- Snapshots preserve the original content and keys. Only the owner receives keys after submission. Changed/held questions block submission of an unfinished bundle. Deleting bank content preserves historical snapshots; account deletion cascades to owned bundles.
- The additive database migration, release index and new `practice-bundles` Edge Function were applied for the gated test stage. Existing endpoint implementations were not replaced.
- `supabase/functions/practice-bundles/http.ts` is pinned to the verified helper used by live `me-tracks` version 8: verified JWT, active profile role and `portal_session` device/session checks. The repository's newer shared helper depended on `portal_mfa_check`, which is absent from this database. The new endpoint uses the current production checks rather than introducing that missing dependency. This does not establish that the separate pending MFA feature is deployed.
- Gateway `verify_jwt=false` is paired with mandatory verified JWT/session authorization inside the function. The endpoint rejects staff and ignores any client-supplied user identity.
- `web/practice-bundles.*`, `bundle-core.js`, `bundle-figures.js` and matching static copies contain the responsive builder, history and runner. User/bundle-scoped offline drafts, serialized saves, conflict handling, invalid-draft rejection and navigation guards preserve work.
- The figure renderer is a scoped copy of the sanitized existing renderer. Original exam rendering is unchanged. Existing PortalMath renders formulas.

## Query performance fix

The cache writer and bundle reader originally used different `search_path` settings. `pg_get_functiondef` then serialized composite argument types differently, so all 2,802 SAT cache signatures appeared stale. The reader now matches the writer's `public,pg_temp` setting. Missing or genuinely stale cache entries still undergo live eligibility checks.

The final successful read-only full SAT catalog observation took 297.552 ms and 12,957 shared-buffer hits, compared with roughly four seconds before the fix. These are single observations, not an uptime or load benchmark. A new isolated regression makes the live eligibility function raise an error, proves that a valid cache avoids it, then removes one cache row and proves the fallback executes.

## Verification

- **71 isolated PostgreSQL assertions passed:** all six tracks; filters/counts; save/resume; retry idempotency; conflicting revisions; owner/enrollment checks; incomplete submission rejection; numeric/fraction grading; separate retakes; changed/held/reserved content; previous-answer sources; preserved old exam scores; service-only grants; rollout gate; stale/missing cache fallback; valid cache reuse; and deletion compatibility.
- **64 Node tests passed, 3 pre-existing baseline tests skipped:** bundle controller, endpoint authorization, pinned production auth helper, navigation, session restoration, mathematical rendering, figures and SAT calculator regressions. A stalled sign-in test verifies the timeout/retry message without opening protected content or creating practice.
- Prior synthetic browser checks passed create → answer → save/leave → resume → submit → review → retake, preserving the original score. Formula, table and diagram rendering and a 390-pixel mobile iframe were inspected. These do not replace a real authenticated end-to-end test.
- The current production browser reached the direct page, but sign-in verification stalled before any bundle API call. One reload did not recover. A backend log confirmed the authentication 504. Security and performance advisor requests subsequently timed out; health returned no notices. The post-migration privilege check before the outage passed.
- Synthetic screenshots remain `PRACTICE_BUNDLES_DESKTOP_2026-11-13.jpg` and `PRACTICE_BUNDLES_MOBILE_2026-11-13.jpg`.

Reproduce local checks:

```sh
node tests/practice_bundles_db.cjs
node --test tests/practice_bundles.test.cjs tests/practice_bundles_dom.test.cjs tests/auth_security.test.cjs tests/practice_bundle_auth.test.cjs tests/navigation.test.cjs tests/portal_math.test.cjs tests/practice_figures.test.cjs tests/session_restore.test.cjs tests/sat_calculator.test.cjs
```

## Remaining release steps

1. Confirm Supabase sign-in and normal database access recover. Do not bypass authentication or broaden the test-account gate to work around a timeout.
2. Deploy the latest saved source with navigation still hidden; verify the server-provided test-account banner before answering anything.
3. With an enrolled test student, create a bundle, save partial answers, reload/resume, finish and submit, review solutions, retake, and verify the original result remains. Check enrollment/course filtering and existing course navigation. Verify saved rows and grading with a bounded database read.
4. Recheck security/performance advisors and current Site source for intervening changes.
5. Only after those checks pass, enable the private rollout boolean and main page navigation flags, build and publish the matching source, and verify the student entry point.

Rollback consists of disabling the rollout boolean/navigation and retaining all bundle records. Do not delete student work or rewrite exam results.
