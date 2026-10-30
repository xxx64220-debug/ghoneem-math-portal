# Examination assignment integration — 30 October 2026

The instructor can select several groups and individual students together, search students by name/email, select search results, and review unique students reached through overlapping selections. The same picker is used by Exams, the Groups entry point, and the existing bulk-exam action.

## Production parity

Before editing, Sites version 121 (source `462b68c44128a25ecef1a1977def565a9865cda4`) was confirmed successfully deployed on the existing portal. Its source already contained the multi-recipient picker, recipient review, independent target assignments, readback/retry handling and deduplicated progress. GitHub main `a66bfbaed4f26acd9051358469fc2ffe64b3d03b` still used the single-target dropdown.

This integration brings those assignment changes and their tests into GitHub without importing unrelated hosting, ACT2 content, registration or reporting changes. The only new production behavior locks the single-exam / group-entry dialog while saving: recipients, dates, cancellation and repeated submissions cannot race an in-flight batch. Controls and selections recover after failure.

## Saving and preservation

A batch uses the existing server-authorized `assignment.save` operation sequentially. It is not an all-or-nothing transaction: successful targets remain saved; failures identify their recipients and can be retried without resaving successes. A lost response is reconciled against server assignments. The existing production `assignments_unique_exam_target_idx` enforces one record per exam/group or exam/student, including concurrent requests.

Existing records and their windows are kept, including expired assignments. Selecting an existing target does not reopen or reschedule it. Direct and group assignments remain independent so future membership changes keep working. Overlap produces one student in the review/progress and one exam card; it does not grant extra attempts.

No database migration, data cleanup, assignment creation, attempt reset, scoring change, question edit or Edge Function deployment is part of this release. The already-applied duplicate-index migration must not be replayed.

## Verification

- 43 assignment, bulk-action and group-interface tests pass against the production source and the narrowly integrated main-branch source.
- An isolated PGlite test runs the actual checked-in assignment writer, access functions and RLS with synthetic data for SAT, EST I, EST II and English. It checks instructor scope, unauthorized targets, duplicates, active windows, overlapping memberships, one exam card / live attempt, attempt limits and unchanged graded history.
- Main-branch client-state regression passes, including answer autosave and assignment progress.
- 21 production-source math rendering, security, CORS and response-header tests pass.
- Production build and the 87-public-text-asset credential scan pass.
- Browser preview was attempted through the supported preview service; the cloud browser returned connection refused. No new visual, physical-phone, Safari or Firefox verification is claimed.
- The broader hosted-source client-state harness has a pre-existing ACT2 fixture problem: its mock creates an absent `act2Collection` element but does not load that module. The narrowly integrated main-branch client-state test passes. This release does not alter the unrelated ACT2 runtime or conceal that harness limitation.

The new regressions cover in-flight resubmission, disabled dates/recipients/cancel, Escape handling, failure recovery, lost-response plus failed-readback retry, uniqueness-conflict reconciliation, and repeated targets within one batch.

