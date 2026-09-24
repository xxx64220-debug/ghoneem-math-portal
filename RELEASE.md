# Verified PDF questions in daily EST practice — 20 September 2026

Confirmed all eight PDFs uploaded in this chat are present in the source registry. Their safe-to-grade content contributes 366 unique, keyed application questions: 249 + 31 + 27 + 9 + 10 + 2 + 38, with one PDF contributing no safe standalone questions. Duplicate, damaged and ambiguous source rows remain excluded.

Expanded the daily quiz pool from the older September 14 batches to every application question carrying a verified release marker, a complete MCQ structure, an answer key and a worked explanation. PDF-based questions with required visuals now return their source assets to the student renderer. Existing daily quizzes remain frozen; the expanded pool applies when each track's next daily set is created.

# Ranked quiz success and PDF export — 20 September 2026

The instructor **Hardest questions** report now ranks every answered question by its real student success rate. It combines assigned quizzes, daily quizzes, lesson exams, and full exams, and shows source, attempts, correct answers, wrong answers, and success percentage for each question.

The report now has a print-ready **Export PDF** action for A4 landscape output, plus a more reliable UTF-8 CSV download that works with spreadsheet applications and delays cleanup until the browser has started the download.

# Quiz mistakes and EST quiz release — 20 September 2026

Added a student-facing **Wrong answers** tab beside Daily practice. It securely loads only the signed-in student's missed daily-quiz questions for the selected track, keeps every historical mistake, and shows the submitted answer, correct answer, source visual when present, and worked explanation. The new service-only database routine is not executable by browser roles.

Published the nine-question EST **Algebra quizz** after verifying all nine question records, answer keys, multiple-choice structures, and worked explanations. The assessment is assigned and open to all 25 currently active EST students. Existing attempts and assignments were preserved.

# Verified question-bank release — 20 September 2026

Published the complete release-ready question set to the existing Ghoneem Math Portal database. The release keeps the current Supabase project and custom domain unchanged.

- 952 unique reviewed questions have answer keys and are present in the live application tables.
- All 18 authoritative source PDFs are stored in the question-source bucket.
- Every question marked as requiring a visual source has an attached PDF-page reference.
- Twelve exact, unused application duplicates were removed; no duplicate source question IDs remain.
- Thirty-two unusable merged OCR fragments were excluded in favor of their reconstructed published records.
- Eleven defective or ambiguous source questions remain withheld from automatic grading.

The GitHub daily-quiz mistake-reporting migration is included in the canonical Site source. Its production view uses invoker security and remains limited to authenticated staff-scoped access.

---

# EST source integrated into the question bank — 11 September 2026

Moved the full 949-entry EST PDF source archive into the Question bank workspace. Instructors can switch between 441 usable questions and all source entries, search by source code/topic/PDF, filter ready versus review-only material, open the original image and analysis, select verified source questions, and create an exam directly from that selection. The 390 verified source questions are selectable; incomplete, duplicate and ambiguous records remain visible but cannot be selected for graded exams.

Validation passed for the merged source list, ready-only selection, exam creation handoff, client initialization and source image decryption.

---

# EST source archive and new assessments — 11 September 2026

Added all 949 source catalogue entries to Instructor → EST source review, searchable by code, section and review status. Each entry preserves its original image and available analysis. Images use authenticated staff-only decryption; provisional answers and source keys remain outside public assets. Student and anonymous access were tested and blocked.

Added 119 complete, independently checked questions, bringing the two-PDF usable bank to 390 questions. Added 20 lesson exams, 11 quizzes and two disjoint full papers (Question Bank Practice 06 and 07), each 50 questions and 75 minutes with 15 FA / 15 DAP / 15 AAF / 5 GT. Answers release after submission. Existing attempts and records are preserved by insert-only imports.

PSD 202 remains held because a company-wide percentage does not establish a department percentage. MIX 024 and MIX 025 have incomplete source content. MIX 045 uses the source cube root, with the corrected explanation. Duplicate and incomplete catalogue entries remain review material, not scored questions.

Validation passed: original-image integrity and decryption, independent arithmetic checks, two complete database grading/deadline tests, key secrecy, instructor/student access isolation, client initialization and autosave regressions. Database test fixtures were rolled back. No browser QA performed. Existing security-advisor notices remain; no new source-review table finding was reported.

Publication order: deploy matching static assets, then apply content/est-september-2026/activate.sql to enable all 33 assigned assessments. Detailed release data and reproducible checks are in that directory and tests/est_september_2026.*.

---

# EST Math 1 question banks — reviewed draft, 10 September 2026

Prepared 271 questions with independently worked answers: 241 from EST_I_Math_Questions_by_Topic-2.pdf and 30 complete questions from Math_Question_Bank_Ghoneem_Clean.pdf. All four domains are covered by 20 lesson exams and 20 quizzes. Five full practice exams each contain 50 distinct questions, last 75 minutes, and follow the source guide's 15 FA / 15 DAP / 15 AAF / 5 GT mix. The five papers do not repeat questions across papers. Lesson exams cover all 271 questions.

All 45 assessments, questions, private keys, and EST assignments have been inserted as unpublished database drafts. Existing assessments, attempts and scores were preserved. The frontend now gives EST-specific exam instructions and allows original diagrams to be enlarged. Answers and explanations release after submission; no official scaled conversion is claimed.

Validation passed: independent local arithmetic and content checks, client regressions, and rolled-back database tests of all five papers for server deadlines, question counts, domain balance, private keys, fraction answers, grading, review release and track isolation. An initial usage-limit rejection was resolved on continuation. Test fixtures were rolled back. No browser QA was performed.

Two printed reference keys were corrected using the worked solutions: AAF 041 is B (−2), and GT 021 is A (21/2). Nine defective or ambiguous topic questions remain excluded: FA 045, DAP 011, DAP 015, AAF 056, AAF 057, AAF 065, AAF 067, AAF 072, GT 022. Detailed reasons and source repairs are in review-audit.json and the review TSV.

The larger Clean PDF has 699 source crops, including fragments, duplicate content, multiple-question crops and answer pages. Only 30 complete reviewed questions are included here; 669 source entries remain unselected, not certified as clean standalone questions.

Release state: validated drafts, not deployed or activated. Publish the saved site version before running activate-after-publish.sql so all diagram URLs exist when students see the exams. Do not re-import or replace existing questions after student attempts. import-draft.sql is insert-only and has already been applied.

---

# Worked March 2026 answer key enabled — 9 September 2026

Independently solved and numerically checked the paper at the teacher's explicit request. Added 50 worked explanations; 47 questions have a single answer, Q23 accepts B or D, and Q4/Q35 are excluded because of defective source data/choices. All original questions, artwork and choices remain unchanged. The scored denominator is 48 and no official scaled conversion is claimed.

Grading supports explicitly recorded alternate MCQ keys and excluded items. Excluded questions remain visible in review, labeled Excluded from scoring, and are absent from score and lesson-accuracy calculations. Worked answers release after submission. Completed submissions are regraded from saved answers, preserving expired status; live attempts are untouched.

Validation: independent numerical checks passed; rolled-back database tests checked the actual 50-question key, 48-point denominator, both accepted Q23 answers, wrong/blank answers, review, excluded-item analytics, expiry, and key secrecy. Existing pending-grading/student-progress regressions and client tests passed. The source PDF and 50 question image hashes remain unchanged. No browser testing was requested or performed.

---

# EST I Math March 2026 — 9 September 2026

Added the uploaded paper as 50 individual multiple-choice questions, in the original question and A–D choice order, with a 75-minute server-enforced timer. Original diagrams, tables, typography and choices are displayed as high-resolution PDF extracts, with shared passages repeated wherever needed. Students can enlarge each question and open the original instructions and formula sheet.

The source contains no answer key and includes defects in questions 4, 23 and 35 (see content/est-march-2026/README.md). Submitted answers are retained with Awaiting grading until a complete verified key is supplied. No guessed marks, partial denominators, or artificial scaled scores are recorded. Pending submissions appear in student history and instructor results; they do not affect average scores or lesson correctness.

Verified all 50 question crops visually against the paper. Rolled-back database tests verified duration, keyless payloads, answer preservation, pending submissions, history and lesson isolation, later grading with verified keys, and expiry. Existing student-progress regressions and client initialization/autosave regressions passed. No browser testing was requested or performed.

Security advisors reported existing helper-function and password-setting warnings; the changed grading/review functions remain restricted to service_role and the results view keeps security_invoker=true.

---

# Student progress update — 8 September 2026

Students now land on a per-track progress dashboard with completed attempt count, average and best raw score percentages, a recent score trend, and lesson priorities.

Separate tabs contain lesson exams, quizzes, full exams, all exam history, and lesson focus. History includes every completed attempt, retakes, expired attempts, and completed exams that were later unpublished. It can be filtered by assessment type and is paginated.

Lesson priorities use the latest released result for each distinct question. Fewer than three reviewed questions produces an insufficient-evidence label. Otherwise below 60% means Focus first, 60–79% Keep practising, and 80% or above Strong. These are practice indicators rather than predicted exam scores. Locked review results are excluded until their answers are released.

Staff can choose the assessment category when creating an exam or change it from the exam list. Existing topic papers were classified as lesson exams; the two warm-up demos as quizzes. Categories and progress remain scoped to the student's enrolled track. No questions or historical marks were changed.

Database regressions verified history, category updates/auditing, priority calculations, retake deduplication, cross-track and cross-student isolation, and locked-review protection. Client regressions verified category separation, history filtering and pagination, escaped lesson titles, initialization, and autosave behavior. Browser testing was not performed.

---

# Portal release — 7 September 2026

Updated the existing public portal and Supabase project without replacing existing question banks, accounts, assignments, or grades.

## Delivered

- Student and instructor sign-in, SAT/EST enrollment isolation, and staff routing.
- Question authoring and atomic JSON bank imports (up to 500 questions per import), with preserved asset objects. Published or used questions require a new version rather than overwriting exam content.
- Exam composition, publishing, group/student assignments, assignment windows, and review release from the instructor console.
- Account creation with username or email, roles, suspension, track enrollment, instructor track permissions, groups, and device revocation.
- Retakes appear on the student exam list; staff select exact exam IDs and set a reason and expiry.
- Answers save immediately, retry every ten seconds, and retain unsynced responses locally. Manual submission waits for saves to finish. A newer answer cannot be discarded by an older save completing.
- Answer writes and submissions lock the same attempt row. Foreign question IDs and late writes are rejected. Late submissions are graded from saved responses and marked expired. The existing one-minute sweeper remains active.
- Per-user start/submit rate limits and transactional idempotency. Same-key submission retries return the saved response; other repeats return a conflict with the existing result.
- Stable per-attempt question/choice ordering, no keys in start payloads, and no review items before the release time.
- Exact per-paper raw-to-scaled conversion maps. No fallback linear estimates are presented as SAT or EST scores.
- Reports, CSV exports with spreadsheet formula escaping, audit history, and responsive staff tables.
- Reporting uses invoker-security views; the roster no longer exposes auth.users through a view.

## Verification

- 48 database acceptance/regression checks passed in a rolled-back transaction on the connected database.
- 25 privilege-escalation checks passed in the same transaction.
- Both frontend scripts pass syntax and mocked initialization checks.
- Client state tests cover offline answer retention, retry success, and a newer answer arriving during an in-flight save.
- All eight Edge Functions deployed successfully. JWTs are explicitly validated with Supabase Auth, current profiles are checked, and session IDs are validated against auth.sessions.
- Browser end-to-end testing was not performed. SQL tests are not a replacement for sitting a full paper in a real browser.

## Content and remaining design requirements

The database contains 354 SAT questions (the original 352-question bank plus two demos) and one EST demo question. The full EST bank is not present in the attached design and has not been invented or imported. Import source questions and verified keys from the Question bank screen.

Exact score-conversion maps must be supplied for each full paper. Without one, the portal reports raw marks. The example values in regression tests are synthetic test fixtures, not official score conversions.

The exam runner remains a timed single-section engine. The design's SAT adaptive two-module routing is not implemented; SAT papers should be treated as instructor-created timed practice. The EST runner is calculator-allowed throughout.

A full backup-and-restore drill, including Supabase Auth data, has not been performed. Existing source versions are retained by Sites; these are not database backups.

## Deployment details

Production application data remains in Supabase. The frontend is hosted on the existing Sites URL rather than the design's suggested Netlify host. Existing public-site access is preserved; exam data and staff functions still require an authorized portal account.

The migration `portal_secure_authoring_and_submission` contains the applied SQL assembled from `supabase/sql/portal_upgrade.sql`, `portal_admin.sql`, `portal_access.sql`, and `portal_scope.sql`. These scripts are the source record for the migration and should not be blindly reapplied.

Run `node tests/client_state.test.cjs` for client state regression checks. The `tests/upgrade_*.sql` files must run together inside a transaction ending in ROLLBACK; do not use the local Auth shim on Supabase.
