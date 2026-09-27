# Final revision question release — 27 September 2026

378 curated existing questions: 254 from the reviewed EST banks and 124 from SAT banks with recorded verification. No existing question, exam, key, attempt or scoring rule is changed. The highlighted Final revision tab is available within SAT and EST I.

## Content

- 30 lesson groups, 208 distinct lesson/idea labels.
- 131 easy, 174 medium, 73 hard. These are editorial practice labels, not official calibrated difficulties. Existing default labels were not blindly reused.
- All 378 prompts and worked solutions were used for classification; EST numeric checks reuse the independent bank verifiers. SAT worked solutions were read during this release. This is a curated release, not a claim that the entire 3,821-question SAT/EST I bank or every possible syllabus variant has been reverified.
- Skills filters distinguish common content and programme-specific extensions. Source filters independently select the SAT bank, EST I bank, or both.
- 53 linked source images, 23 embedded source images and one SVG are preserved. All local targets exist; embedded images decode. The 584 dollar-delimited SAT math expressions parse in KaTeX 0.16.9. EST monetary dollar signs are isolated from math delimiters.
- Prior blueprint exclusions remain excluded. Four further items are omitted; reasons are in `exclusions.json`. No live bank item was edited or deleted.

`manifest.json` is the exact release list, including fingerprints of prompt, choices, assets, answer and explanation. `audit.json` lists coverage. Source snapshots and answer keys are not shipped with the browser.

## Practice behaviour

Sets contain up to 10 or 20 distinct questions. Mixed difficulty aims at 30/40/30; availability may reduce a small lesson set or change its mix. Selection spreads questions across lessons/ideas, favours unseen content and balances sources when eligible. It does not follow official exam percentages because this is revision practice.

The server saves each checked answer, supports equivalent numeric responses and multiple accepted answers, and reveals only that question's solution. Checked answers cannot be overwritten. Unfinished practice can be resumed; completed sets support retrying only mistakes. Revision stays separate from official scores, daily points and exam attempt limits. It has its own mistake retry, not the existing exam mistake notebook.

## Deployment

1. Apply `content-releases/2026-09-27-final-revision-schema.sql`.
2. Apply `release.sql`; it aborts if any reviewed content changed or is held.
3. Deploy `supabase/functions/final-revision` with its shared HTTP dependency and JWT verification enabled.
4. Publish `web/index.html` and `web/final-revision.js`, mirrored into `dist`.

Tables enable RLS and explicitly deny anonymous/authenticated direct access. RPCs are SECURITY INVOKER and service-only. The Edge Function verifies the user and student role; the RPC checks active enrollment and ownership. Catalogue payloads contain metadata only. Sessions hold a private frozen snapshot so later bank edits cannot change an answer mid-set. New sets exclude changed fingerprints and held content until it is reviewed again.

## Verification

- `node tests/final_revision.test.cjs`: filters, feedback, numeric alternatives, stale-track response isolation.
- `tests/final_revision.sql`: rollback-only integration gate against the full release and two eligible students. Checks 20 distinct items, 6/8/6 balance, mixed sources, key hiding, ownership, invalid question rejection, grading, resuming, immutable answers, retry selection, filters, numeric equivalence and permissions. **Not an isolated-CI fixture:** do not point CI at production or add production credentials.
- `python tests/est_bank_2026.py` and `python tests/est_september_2026.py`: passed.
- Browser visual QA could not run: the environment's Chromium download returned invalid archives. No full browser or authenticated end-to-end pass is claimed. Responsive CSS uses 3/2/1 lesson columns and 4/2/1 filter columns.
- The checkout's older client-state harness initially failed on its pre-existing missing `renderQuestionMath` dependency; the repository's current harness is preserved when synchronising changes.

Formulas and lesson-rule notes are intentionally outside this questions-only release.

## Focused collections

Priority revision is the default collection, combining 204 distinct questions across 116 ideas. Its categories overlap:

- **Must know:** 88 representative questions for 88 explicitly selected core lesson/idea pairs. The easier reviewed representative is preferred when several questions teach the same skill.
- **Most repeated ideas:** 110 questions across 22 lesson/idea pairs, each represented by at least four different questions in this reviewed 378-question bank. Exam reuse is not counted. This is bank frequency, not official SAT/EST frequency or a prediction.
- **Unique approaches:** 32 manually selected questions across 32 ideas, with concise method takeaways shown after checking an answer. The set contains 1 easy, 2 medium and 29 hard questions.

Focused sets select only one question per lesson/idea pair and cap their size at the number of eligible ideas. The full revision bank and mistake retries retain question-level selection. Programme, source, lesson and difficulty filters still apply.

`focus.json` records collection membership and reviewed-bank counts; `focus-audit.json` provides totals. Apply `content-releases/2026-09-27-revision-focus-schema.sql`, then `focus-release.sql`, then deploy the updated Edge Function and frontend. The release checks all existing fingerprints before updating revision metadata. It does not edit question content or answer keys.

`tests/revision_focus.sql` is a rollback-only integration gate for counts, distinct ideas, filters, small-set caps, state persistence, and hiding method hints until an answer is checked. The JavaScript test adds collection navigation and feedback rendering checks.
