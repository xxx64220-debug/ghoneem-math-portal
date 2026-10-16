# Formulas and all-course diagnosis verification — October 15, 2026 (Cairo)

The deployed Site source already includes the October 12 dedicated Formulas destinations and all-course diagnosis rollout. GitHub main inspected for the task ends on October 10 and is not the current hosted runtime. This change builds on Site source c4e54f9b304502dc37135b9bc666660336a334e6, including the October 15 group isolation and unlimited lesson selection updates.

| Capability | SAT | EST I | EST II |
| --- | --- | --- | --- |
| Independent student and instructor Formulas destination | Present | Present | Present |
| Course lesson catalogue, worked examples, accessible SVG diagrams | Present | Present | Present |
| Student exact-attempt diagnosis and focused formula/revision links | Present | Present | Present |
| Instructor Overall/exact-exam group diagnosis and revision links | Present | Present | Present |
| Staff RPC selects latest completed scored attempt and respects release locks | Present | Present | Present |

## Remaining gaps repaired

- Student exam lesson resolution now trims explicit metadata before falling back to the topic, matching the existing staff SQL. `Mixed / untagged` and `Unclassified questions` do not produce a false named-lesson recommendation.
- Student bottom-skill recommendations reject blank/invalid percentages, unnamed or unclassified lessons, insufficient evidence and explicitly foreign tracks. Duplicate lesson rows follow the same evidence preference and stable ranking as the instructor planner.
- Instructor evidence also rejects whitespace-only percentages. Source evidence is never mutated.
- Student and staff script cache versions advance with their matching `dist` copies.

## Verification

- 65 tests passed across all-course navigation, group-planning DOM, formula content, student/instructor diagnosis, lesson taxonomy, navigation, hardest-question loading and Final Revision.
- `node tests/group_exam_evidence_db.cjs` passed in isolated PostgreSQL WASM, including metadata whitespace/topic fallback parity, all-course permissions, latest attempts, review locks, foreign questions, aggregate-only output and preservation of stored grades/attempts/answers/assignments/keys.
- Formula regression adds independent calculations for slope, quadratic vertex, circle radius, combinations/permutations, complex division and unit conversion; SAT Desmos restriction syntax remains checked. These are representative content checks, not a new certification of every question in the bank.
- Desktop/mobile Playwright cases now exercise student Formulas lesson selection and exact-attempt diagnosis for SAT, EST I and EST II, plus instructor Formulas/course switching. Existing mocks and CSV/no-retest assertions were brought into line with the deployed interfaces. Browser files pass syntax checks. **Browser execution and visual mobile rendering remain unverified in this environment because the supported browser-control capability is unavailable.** No alternative browser was installed or started.
- Production was inspected read-only: `staff_group_exam_evidence(uuid,uuid[])` has MD5 `fe3dd234bfae777ba1747a121b40dd0d`, matching the October 12 release. It is STABLE SECURITY DEFINER with empty search path, anonymous execution revoked, authenticated execution granted and explicit staff/track/enrollment/owned-group guards. No production tests or data writes were run; the October 12 SQL was not replayed.

No schema, grading, question-bank, assessment-format or historical-result changes are included. Rollback is the prior Site version; no database rollback is needed.
