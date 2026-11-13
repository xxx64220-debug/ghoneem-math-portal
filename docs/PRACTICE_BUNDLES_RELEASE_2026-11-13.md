# Practice bundles — release checks completed

The student Practice bundles workspace is integrated into the main portal, with a home shortcut and a course-specific navigation link. Active enrollment controls access for SAT Math, EST I Math, EST II Math, ACT II Math, EST English and SAT English. ACT means the existing ACT II course; no new standard ACT course or duplicate group site was created.

Students choose a main topic, lessons, difficulty and 1–100 questions. Exact question IDs do not repeat within a bundle. Previously answered questions can be excluded; similar ideas may still occur. Partial work saves and resumes, submission requires all answers, completed work displays choices and solutions, and retakes retain separate results. Existing exams, assignments and Daily Quiz scores are unchanged.

## Live verification, 13 November 2026

Supabase recovered from the earlier authentication/database timeouts. Testing used the existing signed-in test student G; no normal student answers were created or changed.

- Created a two-question medium SAT Geometry bundle, answered one item, saved and left, resumed, reloaded and verified the saved answer.
- Submitted one correct and one deliberately incorrect answer. The UI and database both returned 1/2, with the expected accepted answer and explanation.
- Created a separate retake. It started unanswered with the same question IDs. Answered both correctly and submitted: 2/2.
- History retained both attempts and the original 1/2 result. Database verification confirmed the parent link and completed snapshots.
- Existing test-account exam attempts remained 55, with the same aggregate score of 54 before and after testing. Bundle results did not rewrite exam rows.
- Live service-role catalogs returned 2,722 SAT, 3,098 EST I, 2,125 EST II, 2,347 ACT II and 390 EST English eligible questions. These are total eligible counts before personal answered-question exclusions, not promises about future bank counts. Browser course selection and lesson lists were inspected for SAT, ACT II and EST II; English uses the same enrolled-course API. SAT English was verified in isolated tests because this test account is not enrolled in it.
- Anonymous and authenticated roles cannot call the service-only RPCs or read snapshot answer keys directly. The Edge Function verifies JWT identity, active profile and the existing portal device/session checks before invoking them.

Original test bundle: `b77814c6-c40a-4fde-8fd3-bf6139dfb238`.
Retake: `7872861b-ce02-41a4-84c2-9ce7d47a4e74`.

## Final corrections and tests

The release preserves Site v187 session recovery and the newer reliability transport/build gates from source commit 78dda94, merged after the remote advanced during validation. It adds the navigation flag, decodes encoded solution units as escaped text (for example m² and m³), and updates the selected course in the URL so reloading preserves it. Decoded explanation content is still escaped before rendering; embedded HTML cannot execute.

Validation: 115 passing application tests across bundle behavior, authorization, navigation, session restoration/recovery, figures, math, calculator and checkpoint integration; three pre-existing baseline tests remain skipped. The merged-source application suite passed after the final corrections. The mandatory session-release gate also passed all 20 of its checks. All 71 isolated database assertions passed, covering six tracks, save/resume, grading, retakes, ownership, rollout behavior, holds, unchanged historical scores and eligibility-cache hit/fallback behavior.

The production catalog cache path was previously measured at 297.552 ms after matching the cache writer's search path. That is a single observation, not a load benchmark. Current security advisors report intentional service-only tables with RLS and no client policies; the pre-existing leaked-password warning remains unrelated to this release. Performance advisors retain an informational unindexed track foreign key and other pre-existing findings; there is no demonstrated failure from those notices in this flow.

## Release configuration and rollback

The private rollout boolean was enabled only after the live checks above passed. Both copies of the main page now enable the Practice bundles navigation. Publish the matching built archive and inspect the visible home/course entry points; never publish an older archive over intervening Site changes.

To roll back access, set `portal_private.practice_bundle_rollout.enabled=false` and disable the main page navigation flag, retaining all bundle and snapshot records. Do not delete student work or alter historical exam scores.
