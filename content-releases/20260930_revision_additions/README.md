# Cross-bank Final Revision additions — 30 September 2026

Applied live as `revision.cross_bank_additions.20260930`: five new revision entries and four reviewed restorations. Question IDs, source stems, choices, answer keys, assets, exam memberships and student histories were unchanged.

## Added distinct ideas
- SAT / Statistics and data analysis / Finding the largest absolute residual / medium / Must Know + Unique.
- EST I / Statistics and data analysis / Reading right skew from a box plot / medium / Must Know + Unique.
- EST II / Functions and transformations / Recognizing an ellipse from trigonometric parametrization / medium / Unique.
- EST II / Functions and transformations / Recovering ellipse semiaxes from area and their sum / medium / Unique.
- EST II / Statistics and data analysis / First whole date above a linear regression threshold / medium / Unique.

“Unique” identifies a distinct revision method, not a claim that a source occurs once in the entire bank. The new entries conservatively use one known source occurrence; none receives Most Repeated.

## Restored verified coverage
- Inverse functions / easy.
- Trigonometric graphs and parameters / easy.
- Trigonometric identities / medium.
- Trigonometric identities / easy.

All four are EST II Math Level 1 sources. Their pruning receipts show representative-cap removal, not a mathematical hold. Removed Math Level 2 representatives had subsequently left their exact slices empty. Original revision difficulty, track programmes, Must Know + Most Repeated tags and occurrence metadata are preserved. Full source images were decoded and viewed again. Image-backed prompts retain the complete authoritative question and choices; no text was guessed.

## Independent solutions and figures
The SAT cricket plot was viewed: the observed point (88,20) is furthest from y=0.2x+1, with residual 1.4; requested response20. The EST box plot was viewed: min4,Q1=6,median10,Q3=20,max30, supporting a longer right tail, keyD. Existing independent source checks cover the three complete text EST II questions, which were solved again: parametrization gives x²/a²+y²/b²=1; a+b12,ab35 gives a7,b5; regression gives N=88+(1187/12)d and first eligible day10=October28.

For the restorations: f(t)=∛(t³+3)+3 at t=∛(-3) is3, keyD; period50cos3x is2π/3, keyB; factoring2cos³B sinB+2sin³B cosB gives sin2B, keyD; right triangle legsx,2x give sin2θ=4/5, keyD. Source options were visually checked.

## Guards and regression
Exact question/key/revision version guards reject changed, held, removed, stale or already represented sources. New entries are track-specific. Duplicate-content checks and the maximum two representatives per track/lesson/normalized idea/difficulty remain enforced. `verify.sql` asserts exact metadata, categories, readiness and coverage for all nine representatives.

`tests/revision_cross_bank_additions.cjs` runs in isolated PGlite, with no production connection. It checks unchanged source data and keys, all nine silent-loss mutations, lost collection tags, source holds, wrong tracks, key changes, stale certificates, Math Level 2 exclusion, duplicate content and transactional rollback on a cap violation. Independent numerical assertions cover the solutions. The existing Final Revision and practice-figure tests also passed. CI includes the new test.

Live verification passed:
| Track | Active representatives | Normalized lesson/idea groups | Held/removed/stale active rows |
|---|---:|---:|---:|
| SAT | 457 | 327 | 0 |
| EST I | 410 | 269 | 0 |
| EST II | 287 | 251 | 0 |

ACT and EST II Math Level 2 exclusions remain in force. No held, ambiguous or uncertified source was reactivated.

