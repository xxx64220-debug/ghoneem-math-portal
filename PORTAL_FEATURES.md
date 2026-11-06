# Ghoneem Math Portal feature inventory

## Production verification — 6 November 2026

- **Hosted baseline:** Site 152, source `aa426c16569896839ce0b2197e6771ab32ee30b5`, deployment `appgdep_6aed073aa8648191a732fba8b077e868`. GitHub baseline `002aee59548b070bd5bdd6e9062e47110cb0a7c7` is a separate source history. Of 77 tracked GitHub `web/` files, 12 differ on the hosted source; the hosted checkout also tracks 1,525 additional `web/` files. Keep Site source as the deployment base until the changes and archives have been reconciled. Do not publish an older GitHub distribution over it.
- **Study completion:** Site 152 contains the read-only progress UI. Live readback confirms `student_daily_objectives.lesson_exam_id`, the security-invoker `study_activity_completion` view, no anonymous SELECT grant, and no authenticated client write access to legacy progress. The view requires a matching course, student and linked assessment, a submitted or graded attempt, and saved answer evidence. Older source notes saying this change is unapplied are stale. Do not replay the SQL. Unlinked activities still need an explicit assessment link; an unavailable read must never count as complete.
- **Alex Tuesday quiz:** The 10 November 10-question, 20-minute quiz is published and group-assigned; new starts open 13:10 and close 13:30 Cairo. The private-backed Today shortcut exists and anonymous execution is denied. Signed-in visibility during that opening window still needs a check.
- **Calculator:** The hosted source uses the official external SAT Desmos link. The embedded adapter is disabled there, despite the approved configuration on GitHub. Preserve the working external link until embedding is verified on the live origin.
- **Catalog:** Production audit **21122** records 19 SAT lesson/skill classifications and three title-only labels for the shorter EST sets (22Q, 20Q and 17Q). Readback found zero unclassified active SAT records by the review-queue criteria. The short sets retain their assignments, content and timers; matching 25-question Set 02 assessments already exist. Audit **21124** records independent arithmetic checks on eight MSET/notes grid-in items without answer-key changes. Another 150 records in that intake still lack that review marker.
- **Checks:** Hosted source passed 25 targeted planner/auth/taxonomy client tests and 31 disposable PostgreSQL completion assertions. Asset manifest verification covered 4,968 assets and 111 local links with zero broken links, and confirmed staged MFA is not loaded. The homepage returned HTTP 200 with HSTS, CSP, nosniff and frame-denial headers. These checks do not replace signed-in validation, physical-device testing or a bank-wide mathematics review.
- **Security decisions:** The MFA implementation remains staged; an owner-controlled authenticator and recovery pilot is required before enforcement. Leaked-password protection requires a supported plan and an Auth configuration decision. No new MFA enforcement or billing changes are included here.

## Historical feature inventory — 15 October 2026

The sections below describe the earlier reconciliation. Use the dated verification above for later deployment and feature differences.

Checked October 15, 2026 (Cairo). The deployed Site and GitHub have separate source histories. This reconciliation preserves the current deployed functionality, records matching backend SQL and tests, and keeps the existing domain, database, audience and historical records.

## Students

- Email/password sign-in and sign-out, portal device/session checks, track selection and entitlement checks.
- One account across SAT Math, EST I Math, EST II Math and EST English, with multiple teaching groups per track. Course dates/status govern new practice; completed history and released review remain available to an active account after expiry/pause.
- Visible Today, Formulas (English Rules reference), Diagnosis, Practice, My mistakes, Exams and Progress destinations; section selector retains lesson exams, quizzes, history, lesson focus and weak-topic drill. Search, main-menu links, current-location display, keyboard skip link and back-to-top.
- Separate reference lessons with worked examples, conditions/common traps, diagrams and SAT calculator guidance. Reference navigation does not reset a saved revision session.
- Full exams, lesson exams and quizzes assigned to the student or any matching group, with open/close windows, readiness gates, stored raw marks and exact supplied scoring maps where available.
- Timed exam runner with server deadline, previous/next, palette, unanswered/flagged state, multiple choice/numeric inputs, figures/tables, autosave, reload/resume and retry-safe submission.
- SAT fixed two-module practice with Module 1 completion required before Module 2, normally 22 questions/35 minutes per module. Official SAT Desmos opens in a separate tab. An accessible, resizable in-exam calculator panel is available. The supported Desmos API adapter remains disabled pending verified production permission and a project API key; no demo key is shipped. Adaptive routing is not implemented.
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
