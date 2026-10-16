# Portal course management release — 10 October 2026

Applies to SAT, EST I, EST II and EST English on the existing Supabase project and domain. Keeps permanent student accounts, assignments, questions, answer keys, attempts and frozen Hardest archives.

## Staff workflow

- **Course access** (admin): filter access/expiry/payment states, search students, edit or renew course dates, record payments already received and read receipt history. Track enrollment and account suspension remain distinct. Existing enrollments retain their status and have no invented expiry dates; administrators set agreed dates. Payments are records, not an online checkout or an automatic permission change.
- **Course plans**: instructors manage their own groups in each assigned track; administrators manage all. Set dates, an exam target and teaching plan. Select up to ten matching lessons for daily quizzes; selected lessons need at least five currently eligible questions. A group without lesson selection inherits track-wide quiz settings. When a student belongs to multiple eligible instructor groups in one track, the newest group is used. First opening freezes that student's quiz context for the day, including legacy global quizzes.
- **Bank usage & cycles**: choose a track, owned group and trial period. First/latest success count each learner once per question. Repeat improvement uses initially wrong learners with repeat evidence. Fewer than three learners is marked as a small sample. Daily quizzes and completed scored exams contribute; Final Revision and ungraded work are excluded. Group scope uses current membership. Current published assignment counts are independent of the chosen response period.
- Question filters identify unused, underused, held, review-pending and reserve questions. An administrator can move questions to reserve after supplying a reason. This changes separate catalogue metadata, preserves exact content/fingerprints, and excludes questions only from new automatic sets. Existing exams, saved quizzes, completed attempts and review stay usable.
- Existing **Hardest questions** archive/export controls remain available. Frozen archives keep their original response-based metrics; the new screen provides unique-student metrics without rewriting old reports. CSV exports explicitly export displayed rows.

## Access and accessibility

A student keeps one account across courses and trials. After expiry or a pause, completed history and released review remain accessible to the active account; fresh practice is denied. A timed exam already started during entitlement can finish to its deadline. Untimed continuation is capped at two hours after expiry. A pause/suspension stops continuation. Late submission of an expired timed attempt can be graded within one day of its deadline. New notification dispatch checks current entitlement before sending reminders or announcements; historical result notices remain available.

Student navigation prioritizes Today, Practice, My Mistakes, Exams and Progress, with remaining sections in a selector. Keyboard focus, a skip link and larger controls were added. English fallback previews preserve paragraphs, underlining, references and safe illustrations.

## Verification and release

- 129 isolated PostgreSQL gates across all four tracks cover effective dates, ownership/RLS, preserved history, course updates, idempotent payments, invalid amounts, group quizzes, catalogue reservation, continuation and first/latest cycle boundaries.
- 92 client regression checks pass, including administration, student navigation, markup safety, copied deployment assets and notification entitlement rechecks.
- The concurrent SAT report/content audit source was merged; its isolated 177-content-guard release checks pass.
- Existing isolated Hardest-cycle, group-exam evidence and paginated-bank regressions pass.
- No tests run against production Supabase. Production verification is read-only before/after deployment.
- Browser control is unavailable in this environment; signed-in desktop/phone visual verification remains pending. Automated DOM and responsive-style checks are complete.

`apply.sql` is a single guarded transactional release. The deployed release uses the equivalent three smaller guarded transactions in `01-core.sql`, `02-integrations.sql` and `03-integrations.sql`, because large connector requests failed with an expired-request-state error. The final report scope correction, `04-report-scope.sql`, was applied to the initial deployed core; a fresh `01-core.sql` already includes that correction. The broad legacy account editor is unchanged; new account operations use scoped functions. Set a student’s course to active/current before adding new group membership through that editor. `preflight.sql` rejects drift in the exact deployed definitions. `baseline-definitions.json` and `functions-before.sql` retain prior definitions. `scripts/management/build-integration.py` regenerates the integration from these checked-in inputs. CI includes the new regression checks.

For rollback, restore the previous Site version and prior database function definitions together. Keep additive course/payment/catalogue tables and their records: rollback must not delete payment or student history. The legacy policy definitions are retained in the repository's earlier migrations. Notification deployment retains the existing live shared HTTP module and JWT/custom worker authentication settings.
