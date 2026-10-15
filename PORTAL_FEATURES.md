# Ghoneem Math Portal feature inventory

Checked October 15, 2026 (Cairo). The deployed Site and GitHub have separate source histories. This reconciliation preserves the current deployed functionality, records matching backend SQL and tests, and keeps the existing domain, database, audience and historical records.

## Students

- Email/password sign-in and sign-out, portal device/session checks, track selection and entitlement checks.
- One account across SAT Math, EST I Math, EST II Math and EST English, with multiple teaching groups per track. Course dates/status govern new practice; completed history and released review remain available to an active account after expiry/pause.
- Visible Today, Formulas (English Rules reference), Diagnosis, Practice, My mistakes, Exams and Progress destinations; section selector retains lesson exams, quizzes, history, lesson focus and weak-topic drill. Search, main-menu links, current-location display, keyboard skip link and back-to-top.
- Separate reference lessons with worked examples, conditions/common traps, diagrams and SAT calculator guidance. Reference navigation does not reset a saved revision session.
- Full exams, lesson exams and quizzes assigned to the student or any matching group, with open/close windows, readiness gates, stored raw marks and exact supplied scoring maps where available.
- Timed exam runner with server deadline, previous/next, palette, unanswered/flagged state, multiple choice/numeric inputs, figures/tables, autosave, reload/resume and retry-safe submission.
- SAT fixed two-module practice with Module 1 completion required before Module 2, normally 22 questions/35 minutes per module. Official SAT Desmos opens in a separate tab. Adaptive routing and an embedded calculator are not implemented.
- Untimed repeatable lesson practice and instructor-led practice; full papers retain their timing. EST I practice uses 50 questions/75 minutes; EST II full practice uses 40/60 where configured, with original imported exam formats retained.
- Scores, awaiting-grading states, delayed/locked review, excluded-question handling, worked explanations, reviewed figures and complete attempt/retake history.
- Five-question daily quiz, selected-track/group bank, eligibility checks, frozen questions once opened, scoring, daily checklist, points/bonuses, Cairo-midnight reset, course streaks, badges and group-scoped ranking.
- Daily wrong-answer review and Mistake Notebook; repeat a question until two consecutive correct checks. Question IDs/figures remain matched across practice modes.
- Untimed weak-topic drills from the lowest evidenced topics, normally 15–18 questions when sufficient eligible content exists, with combined grading and a new-set action.
- Final Revision by lesson, difficulty and collection: unique questions, most repeated ideas and must-know ideas; numeric/MCQ checking, saved progress, solutions and retry mistakes. Held/unready content remains excluded.
- Progress summaries, distinct reviewed-question topic accuracy, lesson focus, score trend and exam history.
- Diagnosis for every course, exact completed-attempt lesson counts, reliable bottom skills, formula/rules and revision/drill links. Missing/ungraded/locked evidence is explicit; error causes and per-question time are not guessed.
- Question/site reporting with stable request IDs, and English passage-aware reading (paragraphs, supported illustrations, desktop split/mobile collapse behavior).
- Opt-in notifications, per-device exam/result/reminder preferences, current-device test, safe taps, PWA installation and offline guidance. Phone delivery requires a physical opted-in device; no announcement was sent during this audit.

## Instructor and administrator

- Overview, results, raw-score/review status, per-student evidence, CSV export, class lesson heatmap and scoped students.
- Separate Formulas/rules and Diagnosis destinations, course chooser, student reports and Group planning: Overall or an exact exam, latest completed scored attempt, common weak lessons, deterministic shared-lesson clusters and supported revision/retest navigation.
- Exam builder, manual/selected bank questions, category, duration, shuffle, review policy, attempt limit, publish/unpublish, assign to student/group with dates, progress, retake grants, release review and untimed teaching preview.
- Question bank: stable 50-row server paging, search/filter/sort, ready/held/pending/solved review queue, lesson/skill taxonomy, selection across pages, lazy full preview/editor and exam-creation handoff.
- Exact EST source review, protected source-image access and verified-version preview for held originals. Provisional/duplicate/incomplete sources remain unavailable for grading.
- Daily quiz controls: random, chosen lessons or selected questions; source/key/choice/hold checks; results and wrong answers. Administrator reset archives prior daily progress and requires explicit confirmation.
- Final Revision visibility, lesson/collection management and ready-item release checks; ready/held guards remain authoritative.
- Accounts & groups plus Subscriptions & payments in one Students workspace: create/edit account and all selected course settings, dates, status, payment state, matching memberships and preferred daily group; retry resumes the same created account after setup failures.
- Administrator account activation/suspension, course access grant/pause/renewal, payment receipts/history and guarded deletion; staff account controls remain separate. Recording payment status does not charge money or create a receipt automatically.
- Independent teaching groups: stable parent track, unique names, instructor, membership, dates, exam target, plan, every parent-track lesson, select-all/clear and stale-edit guards. Default cohorts are protected; paused/future members stay visible. Multiple groups provide all matching exams but one preferred daily quiz per course/day; automatic mode uses a sole active group or the parent settings.
- Bulk selection for accounts, exams, device revocation, course access/dates/labels/payment status, course plans and reserve/restore. Same server permissions as individual edits, target/track guards, staged outcomes and failure retry; not a single all-or-nothing transaction.
- Bank usage & trial cycles: unused/underused/held/pending/reserve filters, unique-student first/latest success, repeat improvement with explicit denominator, group/current-membership and trial-period scope, small-sample notices and displayed-row CSV.
- Hardest questions: response-based success ranking, reliable paging/cancel/retry, current/all/archived cycle selection, immutable archive and new-cycle action, CSV and print-to-PDF export. Existing grades are preserved.
- Reports queue/search/status/staff note/question preview; browser-reported exam activity list/details (context indicators, not a cheating verdict).
- Device/session management, audit log, and administrator notification announcements/history for opted-in devices with message review before sending.

## Evidence and limits

159 current Site JavaScript tests pass. 110 focused tests pass against the reconciled GitHub files. Seven isolated database suites pass, including 129 course-management gates, 26 group-isolation gates, cycles/history, bank metadata paging, exam diagnosis permissions, question readiness and reported-SAT repair preservation. No tests connect to production.

Read-only production checks found all 15 Edge Functions active, with deployed `staff-console` and `student-groups` source matching the reconciled files; all inspected public staff/application RPCs deny anonymous execution. Both expiry and push cron jobs are active. Notification configuration is present (values were not disclosed); ten opted-in device subscriptions exist. Published exams have zero missing or cross-track question links and zero empty papers. Final Revision controls are visible on the three math tracks.

The public portal homepage serves the current deployed diagnosis script. All 53 literal local script/stylesheet/image references in top-level served HTML resolve in `dist`. These checks establish source/backend availability, not authenticated end-to-end completion on every account or a phone-delivery guarantee. Backup/Auth restore was not exercised. Representative formula calculations and bank rendering are covered; this functionality audit does not certify every pending question's mathematics.

The integration repair keeps Formulas and Diagnosis visible after the later dashboard layout wrapper runs. Combined-script tests prevent either from silently returning to menu-only access.

All numbered release packets included here are source/receipt records already applied to the existing database. They must not be replayed merely because this GitHub reconciliation merges. Content-only PRs are handled separately; their data patches are not part of this runtime reconciliation.
