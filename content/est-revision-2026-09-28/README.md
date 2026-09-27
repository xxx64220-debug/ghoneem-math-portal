# EST I revision expansion — 28 September 2026

530 EST questions, up from 254; 33 lesson labels and 239 idea labels. The 124 SAT-source revision records remain available on the SAT track. EST I catalogue, generation, old-session resume, answers and retries are restricted to EST-source questions on the server as well as the interface.

The collections overlap: 321 must-know questions, 249 questions representing ideas with at least four reviewed examples, and 51 distinctive questions. Priority revision combines them into 390 questions. Focused sets still choose one question per idea. The 30/40/30 easy/medium/hard mix is an editorial practice target, not an official EST blueprint or frequency claim.

| Reviewed source | Included |
|---|---:|
| EST topic PDF | 235 |
| Ghoneem clean question bank | 153 |
| May 2026 | 50 |
| March 2026 | 46 |
| December 2024 | 46 |

The inspected candidate pool contained 542 records. Twelve were excluded: three exact duplicates and nine questions needing clarification or containing a source defect. See exclusions.json for exact identifiers and reasons. March Q4, Q6, Q23 and Q35 are excluded from this revision. This does not change the paper's existing grading policy. No separate May 2025 paper was found in the available exam records.

AAF 030 had a correct answer with an unrelated polynomial explanation; the explanation now solves its actual radical equation. FA 012's confusing graph transcription was replaced with a clean question referring to the original diagram. Neither correction changes an answer key. The release checks each content fingerprint before and after changes and publishes corrections and metadata atomically. Existing session snapshots containing those two questions: zero at release.

## Material still needed

These are gaps in the reviewed EST collection, not a claim that every requested skill is on an official syllabus. Please supply the instructor's lesson outline and approved examples to settle the intended scope.

| Lesson | Current questions / ideas | Useful additional material |
|---|---:|---|
| Logarithms | 1 / 1 | Definitions, log laws, domain restrictions, change of base, easy and medium examples |
| Sequences | 2 / 2 | Arithmetic and geometric sequences; nth terms and sums, if taught |
| Statistical inference | 2 / 1 | Sampling bias, study design, inference and margin-of-error examples, if taught |
| Quadratic inequalities | 3 / 3 | More sign charts, repeated roots and inclusive/exclusive endpoints |
| Expressions and number properties | 4 / 2 | Divisibility, factors, remainders and parity examples matching the lesson outline |
| Complex numbers | 7 / 2 | More distinct ideas beyond arithmetic/powers and conjugate division |
| Graphs and data interpretation | 14 / 2 | Medium/hard multi-step graph and table interpretation |

Formula and rule content is awaiting the instructor's supplied material. No new formula claims were added.

## Verification

- Reread all 254 retained EST prompts and solutions; reviewed all 288 additional candidates.
- Visually inspected the 121 attached new topic-bank source images and March Q1–50; inspected May tables, plotted figures and graph choices.
- Existing source verification passed for the topic banks, March keys and all 46 December items. May keys were independently solved; tests/est_revision_expansion.py checks its arithmetic and algebra, domains, counterexamples and both corrections.
- All 201 May mathematical expressions parsed with KaTeX 0.16.9. Currency in plain EST text and HTML tables is separated from math delimiters. 216 selected hosted question images exist in deployment output.
- Transactional database tests passed for counts, EST-only filtering, all collections, hidden answers/hints, ownership, grading, immutable submissions, completion, retry, legacy mixed sessions and SAT continuity. Test progress was rolled back.
- Frontend logic and script syntax checks passed. A full authenticated browser interaction pass was unavailable in this environment; no claim of completed browser end-to-end QA is made.

Manifest fingerprints keep later unreviewed source edits out of newly generated sets. This release reviews the stated 542-record candidate pool; it does not certify the entire larger portal question bank.

Rebuild metadata with `python scripts/build-est-revision-expansion.py`. The guarded release SQL is an initial application script, not an idempotent migration: rerunning after its two source fixes intentionally fails the original-fingerprint check.
