# EST II final revision and portal controls

Released 28 September 2026 (Africa/Cairo).

416 EST II questions across 27 lesson groups and 289 descriptive idea labels. Includes Level 1 and Level 2 papers from December/October 2020, May/June/October 2021, and Level 1 Sample 4. All are sourced from the existing independently worked, visually verified paper import dated 26 September. There is no SAT or EST I question crossover into EST II revision.

The 418 candidate solutions were reread for this selection. All original image hashes and image decoding, source provenance, answer-choice membership, explanations and current database fingerprints were checked by the build script. This release reuses the earlier visual verification; it does not claim a second visual inspection of every crop. Two ambiguous questions were excluded (see exclusions.json). Their original source records were not rewritten.

Difficulty labels are editorial, not official exam weightings: 226 easy, 82 medium, 108 hard. Mixed sets target 30% easy, 40% medium and 30% hard, falling back when a filtered lesson lacks a level. Collections overlap: 174 must-know, 111 repeated-idea examples, 57 distinctive questions. Repeated means recurring in these nine available papers, not a claim about every EST II exam. Priority sets avoid duplicate lesson/idea pairs.

## Coverage needing more source material

Vectors and number properties each have only two questions; graphs and models has four. These categories need more supplied papers/questions before calling coverage comprehensive. No March EST II paper was present in this reviewed pool. The formula and rules reference is deferred until the teacher supplies it.

## Admin use

Select a track, then use the top tabs or grouped Go to section menu.

- **Daily quizzes:** use the verified bank, selected lessons, or selected questions. At least five eligible questions are required. Selecting exactly five fixes the set; larger pools rotate daily. Once any student opens today's quiz, today's questions remain fixed. New selection settings apply to future quizzes.
- **Scores and resets:** admins can reset one student's one date or all daily dates for the selected track. Quiz-only resets retain focus/review ticks and clear quiz answers, score, points and completion bonus. All-progress resets also remove checklist history. Type RESET to confirm. Previous rows are stored in a private archive. Assigned exam marks are unaffected. Historical resets change history and streak calculations; bonuses previously earned on other dates are not retroactively recalculated.
- **Final revision:** show/hide access for a track. Filter by lesson and select shown questions to release/hide that lesson, or select individual questions. Hidden items stop entering new sets; saved sets retain their snapshot. Hiding the whole revision blocks both new and saved sessions while preserving progress.
- **Reports:** student question and functionality reports appear in a private queue with status and staff notes. The question is attached automatically. Admins see their selected track; instructors see their own reports and their assigned students' reports within authorized tracks. No email delivery was configured.
- A Main menu button is at the top of exam and revision review. Reports are available in active exams, reviews, daily practice, notebook and revision.

## Validation

- `tests/portal_controls.sql`: rolled-back integration checks for EST II separation, answer privacy, visibility/release, report retries/track scope, selected/lesson quizzes, frozen quizzes, score resets, archives and role permissions. Uses a disposable track; no real student scores were reset.
- Existing `final_revision.sql`, `revision_focus.sql`, `est_revision_legacy.sql` passed against the expanded backend.
- 18 affected JavaScript checks passed, including 5 new control checks; syntax and web/dist parity checked before publishing.
- New tables use RLS with no browser grants. Only authenticated edge functions call private service-role RPCs. Supabase advisors found no new security warning; RLS-with-no-policy informational notices are intentional for private tables. Added the reset archive track index identified by the performance advisor. Other existing findings were left unchanged.
- Browser interaction was not run because the environment's Chromium installation was unavailable.

Apply the portal controls schema before release.sql. The latter validates current question fingerprints and updates only revision metadata; it preserves prior item release choices. Metadata and SQL remain outside the public site bundle. Regenerate with `python scripts/build-est2-revision.py <private-question-pool.json>`.
