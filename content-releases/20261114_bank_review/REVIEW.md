# Question-bank review — 14 November 2026

Status: applied as two guarded content releases plus a guarded Final Revision catalogue refresh. The Practice Bundles software draft (PR #56) was not deployed.

The user authorized reviewing all courses, making verified good questions live, and repairing what could reliably be fixed. This review audited availability across the entire bank and independently checked the mathematics of the released/repaired items. It does **not** claim that every existing question has been newly solved and mathematically certified.

## Results

- 44 previously eligible but unreleased questions made available: 36 SAT and 8 EST I.
- 82 independently checked ACT Math II adaptations published: 12 in the first transaction and 70 in the second.
- One existing correct cylinder version reused instead of creating another similar question.
- 87 defective source records linked to reviewed replacements; repeated source copies share a single replacement. Their originals remain held.
- 14 existing SAT questions corrected: eight unrelated cover images removed, including two explicitly clarified statements and one replacement diagram; MSET014 Q38 now explicitly states its required 90° central angle; five answer-sheet references replaced with worked explanations.
- Every pre-existing accepted answer is unchanged. Exams, assignments, scores, submitted answers/results, notebooks, and saved practice snapshots were protected against writes by in-transaction hashes.
- No new feature, schema, hosting, group-membership, or question-exclusion policy was deployed.

## Availability after release

| Course | Total records | Available for practice | Eligible but unreleased |
|---|---:|---:|---:|
| ACT Math II | 2,725 | 2,429 | 0 |
| EST I Math | 3,965 | 3,106 | 0 |
| EST English | 390 | 390 | 0 |
| EST II Math | 2,337 | 2,125 | 0 |
| SAT Math | 2,802 | 2,758 | 0 |
| SAT English | 8 | 8 | 0 |

Total: 12,227 bank records; 10,816 available. All groups use their existing course enrollment and access rules.

## Remaining holds

| Category | Records |
|---|---:|
| duplicate | 200 |
| original with reviewed replacement | 168 |
| unresolved source or content | 157 |
| instructor exclusion | 886 |

The 157 unresolved holds comprise 144 ACT Math II and 13 EST I source/content issues. They include missing or clipped source material, unrecoverable diagrams/labels, unsupported proof/drawing tasks, and ambiguous or inconsistent conditions. They were not certified or silently released. Additional repairs need reliable source evidence or a separately specified instructor adaptation.

Previous exclusions remain in force: ACT-source material, logarithms and sequences excluded from EST I; Math Level 2 excluded from EST II. Existing SAT and EST II defective sources already have reviewed versions and were not reimported.

## Validation

- 51 independent mathematical checks for the first release.
- 85 symbolic/numeric checks covering every one of the second release’s 70 adaptations.
- 118 and 297 disposable PostgreSQL checks, including late question/key edits, late student answers, duplicate adaptations, transaction rollback, course isolation, historical preservation, and repeat-run rejection.
- 560 content fields passed the existing portal mathematical renderer, including fractions, radicals, matrices, complex numbers, inequalities, and currency; repeated rendering was stable.
- 11 existing renderer/verified-version regression tests passed.
- The replacement angle diagram was rendered and visually inspected. This is a content release; no new full-site mobile/desktop deployment claim is made.
- All three actual production transactions first passed an identical rollback-only rehearsal, then committed successfully.
- Final readback: zero eligibility-cache mismatches, zero ineligible released questions, zero defective originals re-enabled, zero invalid replacement links, and zero eligible-but-unreleased questions.

## Final Revision integration

All 51 reviewed SAT/EST I catalogue entries were refreshed against their corrected content fingerprints; 16 previously inactive reviewed entries were activated. Saved session snapshots were preserved. The two mislabeled lessons were corrected in both question metadata and the revision catalogue: parallel-line angles → Angles and lines; absolute-value equations → Inequalities and absolute value. A live read-only catalogue call using a staff-designated test account confirmed all 51 reviewed items visible in SAT’s combined catalogue and all 8 EST I items visible in EST I.

ACT Math II questions are available in its question bank and existing bank-based assessment/practice paths. The legacy Final Revision RPC still supports SAT, EST I, and EST II only. Expanding that interface to all groups remains part of the separate Practice Bundles draft; no application code was deployed here.

## Exact records and reproducibility

- `manifest.json` / `apply.sql`: first release, 65 guarded updates and 12 inserts.
- `manifest_supported.json` / `apply_supported.sql`: second release, 73 guarded source-link updates and 70 inserts.
- `sync_final_revision.sql`, `revision_sync_before.json`, `revision_sync_after.json`, and `revision_live_catalogue_check.json`: fingerprint/activation, lesson-label, and live catalogue evidence.
- `full_candidates.json`, `full_repairs.json`, `supported_before.json`, `supported_extra_before.json`: pre-change question/key snapshots. No student records are included.
- `post_rows.json`, `supported_after.json`, `final_access.json`, `final_integrity.json`: post-commit receipts.
- Build scripts and tests are in `scripts/` and `tests/`.
- Reapplying either SQL file intentionally fails its original-content hashes; it must not duplicate rows. To reverse a release, use the snapshots to prepare a newly guarded change after checking current attempts. Never delete newly attempted question records or recalculate old scores.

## Repair catalogue

| Source question | Published version | Lesson |
|---|---|---|
| 1115c92c-eca5-5c40-b42f-f782066e4eff | 8939b729-8bd1-51df-8977-55604d2a2685 | Trigonometry |
| 2da9d842-d0a0-5b81-a3e7-831e75a4f515 | 408891c1-3d35-5197-8b59-dc5a2976bce0 | Logarithms and exponentials |
| 98cb24bf-e675-5d2e-a4c0-bd834cbbc0f2 | cb2bb778-72a0-5a82-9020-f02afd4a2f9f | Trigonometry |
| a66e7923-397b-5cd5-995c-04205246199d | 3cae9561-7bf7-525b-98ac-d5bcdaf42b5f | Circles |
| d0ffb261-513f-551b-88c4-9b6845e98178 | b5a5f8a4-5298-5c01-bbc0-4459b3f92ac4 | Circles |
| 9b4f5a2d-27d7-5210-922a-31e2556e7130 | 675a3178-810f-5531-8d6b-6497f8e7783d | Quadratics and polynomials |
| 9b45a010-891a-5c72-aeb0-4346e6f82c3f | 0828b97c-3414-534e-8ed4-db26d79079a8 | Statistics and data analysis |
| 93b5da55-a8b7-58f0-a38c-4e4fc3d1fcb1 | c7f7ee46-421c-5022-ba22-5c9ae0c1b5b6 | Statistics and data analysis |
| a7e0c938-c48b-50d8-88b3-8388c07f0560 | 4236b337-2e07-522f-aee7-58ea04c01fd7 | Circles |
| e79575f2-6d3f-55d4-a583-f6b42f9f949e | 1840ed87-8e41-51f1-8ded-51622e9abc33 | Complex numbers |
| fddc7217-091d-5eb2-9649-52643c66cac0 | 4a6bf68a-0db8-57eb-a159-7142ddc2aac7 | Angles and polygons |
| b6763c00-7ba0-5573-a0ce-4434dd00d24c, c0edf793-69ae-51f1-9c63-00444e743f84 | 771caf47-a5b8-508f-8b51-b6a4cf225aa8 | Ratios, percentages and unit conversion |
| 074ada07-ac7e-53b6-adf6-0f9d4b5baf9d | 91a7a5bf-b1b8-51ac-9a5b-8dedb72ed64f | Logarithms and exponentials |
| 09ecb437-4fe7-557d-80f8-dcd74efcc638 | 7f4aefc3-6447-5a2c-86da-69e65b787219 | Functions and transformations |
| 0eea2617-8e7a-50e6-98da-152f0ba6399b | 4ba3a6bf-3235-599b-8e77-dba0f96dc9d3 | Functions and transformations |
| 1598aea2-88e9-57a6-91d4-c0fb8006ccc7, 6cb27c03-9ab5-5513-ab59-b2554829b6f7 | 405063fb-1cda-510e-a298-e2c8adfe6194 | Inequalities and absolute value |
| 16b328b4-5d7c-5bc5-bef8-72bc866070cd | 1aba05bd-f31c-58b7-9105-4421e370c33a | Complex numbers |
| 172ad291-1971-5b92-80b0-8e96aaa0840b | 8843f032-e921-5a52-ba56-30a7a202af73 | Functions and transformations |
| 17976d6c-2ce8-5351-ab19-3ebc0e121401 | 94c1ad64-0fca-5d8a-9d0b-c389810da2df | Circles |
| 26abc145-8b08-53fb-adc9-a7f97337dd01 | 71a87f1b-2153-5161-9618-381aa950b157 | Matrices |
| 28077444-a86b-578f-a01d-d683174a6783 | 1295d970-be8f-5b87-87a4-7807f1af0f51 | Systems of equations |
| 296355c1-7527-5138-9fc7-817c0fd90602 | ab951b70-9b72-5033-96e0-1e20086513ab | Functions and transformations |
| 29abef4e-6d2b-598b-b3d7-8547eb71669f | 0fdeaf39-0f6c-5ee6-91a1-83d013db2bc1 | Exponents, radicals and growth |
| 2c17ac10-8a80-5b26-a542-0a3a88b7a70f | 5f1f6d29-2084-57f1-8954-4c6a146e70de | Matrices |
| 317d7cf1-2ca9-50fb-bfdf-74d0d07fc006 | 5f83503f-cebf-58fe-b24e-cc97379643a5 | Quadratics and polynomials |
| 36341e49-d169-59ba-8f93-ca0c9a8867ee | bb29bf23-3231-5dba-be89-5e44d78d5df2 | Inequalities and absolute value |
| 38daac79-8b25-5a6e-924d-71c29e92e8f5 | ea79f566-d085-501f-a4ea-69347d318040 | Functions and transformations |
| 3ba6f5a2-9de0-5bd8-a70d-e37763fd5bad | 2bc02fd5-52c0-5b3d-8cab-423bc9707d26 | Systems of equations |
| 3ec0a5f0-2e42-53d5-9bf6-2e27b9b2985d | ccb9dcb4-8320-5d0b-958c-56167c864119 | Systems of equations |
| 3f396c88-1a15-5528-a80d-4b6908ef651d | 48079742-6efe-5cd9-8dfb-d665c03075ad | Volume and surface area |
| 451f180f-a518-5d02-bca5-5abe6f0be0a6 | 86089731-aab4-5e69-9545-b3d151dfa5ba | Quadratics and polynomials |
| 46097bfa-1393-513b-bb2a-502cd7452b48 | d0deeb38-74cc-5679-b855-7e059204ccf2 | Linear functions and slope |
| 4820eb3d-0cd3-5071-a436-6d0bfdd740c3 | 2e3e43ae-4974-5496-885d-9e08e426857d | Exponents, radicals and growth |
| 48c8b9b8-0a69-5c22-807c-42fb0ee01676 | 980d2e39-b4bc-5f94-98fb-cdf130df75fa | Linear functions and slope |
| 49104dc3-4932-5524-93e7-84085561b37e | 7503fb1e-bc67-5d05-9529-ee0fa3eaa80b | Functions and transformations |
| 59256413-ae79-52e9-9dd6-20dc9f415907 | b6ef1b04-da89-501e-8457-c4aa712d7762 | Complex numbers |
| 59721de1-67ec-5876-a650-5b4aa2b300d6 | 7349c3ca-0363-5262-9898-0a00dc724b4c | Systems of equations |
| 5f033576-cad3-5794-a034-bfb20c353a99 | 4210a4cc-e2ab-5a99-8beb-c0ff1a1e82d8 | Complex numbers |
| 5f17833f-59b6-5a32-aae1-633a7b94b22b | 9949d0d3-4ef5-5efb-9909-cbb738769588 | Functions and transformations |
| 6037be14-ef15-5157-97d8-02acb6ed343a | 17748abd-1dc8-519c-966d-8b19268844ac | Conic sections |
| 61a51dd3-cf3c-5b42-98bb-01fd84509e3e | d6e5c1c8-c3a0-5539-9739-399e2ebb49b0 | Quadratics and polynomials |
| 61c9e3fb-22bc-5c8d-9901-d94ffcee5ea2 | 46ed12b1-efe3-5097-83ec-87b624ddcb8f | Circles |
| 69b73d1b-f316-59f3-8eaf-799f8e00226f | 1d81f8b6-17db-5155-ad3d-a793d5a30bc6 | Linear functions and slope |
| 6b29ba68-ed8f-5d95-8f94-3a747dc9884b | ab16a410-6392-5656-a605-7d8c626a764c | Functions and transformations |
| 6c698a69-c0ab-5b1a-b503-43b48529cfb2 | b7c5a438-c1d9-5423-8514-dd3226282ced | Triangles and similarity |
| 737364bf-2739-5a73-b908-50a94bc81ddd | 5fa6193a-29ad-5157-8a3b-7a573b2e55a8 | Ratios, percentages and unit conversion |
| 7e911655-761e-5421-adf0-fcb38a8d2152 | d7a16540-0ed6-58fa-a0d8-09a0f4528162 | Area and perimeter |
| 7f518a2a-d7b8-5640-9702-bbcaaa987992 | 45f52837-6f8e-5f66-80c1-189c51b93400 | Trigonometry |
| 84d52170-2e92-51ec-a620-42197786d56a | 78cb4eb4-82a3-5a95-9e72-f90cc865f3f6 | Exponents, radicals and growth |
| 89153e97-2b10-59c9-8e19-494a3f97c1b8 | 7bd37aec-acba-5916-a75c-92c5a9c04090 | Functions and transformations |
| 8b343527-1eac-5295-925b-1dfc4d2730a3 | cee68d87-128b-50eb-a847-596666a592a2 | Quadratics and polynomials |
| 8b8cfb7a-6df2-5ee6-a045-80a1ef7a79af | d9b9f20b-cf36-54c6-8cfc-924c6a2a2980 | Angles and polygons |
| 90f77567-6ac9-5fcb-829b-82cfb02c298a | 91fa78d1-f523-54d9-b3b4-1bcb41333de0 | Linear functions and slope |
| 967c3d8b-4109-5b7a-9c45-1b287d076018 | db18c258-0bbc-5d41-9b59-190f17b111dd | Conic sections |
| 9a06ec43-8291-520f-b1e8-0b6657539920 | 18119073-f571-5c55-a2cf-6a83db3a86be | Inequalities and absolute value |
| 9dff9f8a-d5d3-548f-9436-909b22aa29a2 | dde33c79-fe47-5df6-ba8f-a68a50dee896 | Trigonometry |
| 9fcd9239-7ac9-5e0c-9251-e69e7f973de5 | bdc3e17f-8827-5d66-8b3f-40edf958caa8 | Quadratics and polynomials |
| a77b0768-4443-5d3d-aa74-b8f53201f661 | 451af467-5eb5-5ab8-8355-b233d3e62ef6 | Quadratics and polynomials |
| a9517d0e-8c62-5ce3-853c-065976dca334 | 217fb843-bd9e-5959-804c-f60285e94a55 | Trigonometry |
| abe5dbb4-442a-5d6e-950b-c57b4f43944f | f3e9bdd2-f4be-5d2e-95af-d3aeff829ec3 | Logic and sets |
| abf3a097-3ae1-56da-99ef-12337dd810a9 | 4c2ecf7a-dc1e-5c10-af6f-70d4b00a60d7 | Quadratics and polynomials |
| cb5328b0-077c-5913-80b3-a38f57a9f966 | 09c043f9-ccbc-58c6-9312-4d208ca0aa10 | Circles |
| d4fabad7-80c7-5751-8297-f0e25fe17be4 | dba9d962-bfde-5bcc-a59c-98d61bf2cf8f | Linear functions and slope |
| dc91cd5c-f2db-56e1-843d-40c3885626f4 | e5d336a1-bdbc-5e32-ac54-120c903ea19d | Quadratics and polynomials |
| dde56c95-4d24-50a6-9fd0-9e867f49e16c | 8557177e-b947-5303-8ba1-38bb80c5df50 | Logarithms and exponentials |
| de4a2e58-5250-542d-8ca1-133cdfc3a22e | 49dafa85-8ab9-5cef-8a7d-707724ce5b6a | Functions and transformations |
| e6c907a4-339c-575b-a5ec-d9cb4bedea4f | 2ab9b29c-73e8-5cca-baf0-8704640ec733 | Exponents, radicals and growth |
| e81728fa-0bfe-500a-b95c-b6a596921bac | 1dfe0bc6-fdc2-5a93-be80-c539bcc4105b | Functions and transformations |
| ec0b80b3-e678-57ca-b685-9f71dd1510b9 | 60734574-7b82-5d2f-a926-bc0f2438319b | Inequalities and absolute value |
| ed1dcc2d-a539-533b-82a8-53b453cd19f7 | 03dfebba-f5bd-5db9-943b-a25b7ca37ffd | Statistics and data analysis |
| f8d3bf78-537b-594e-bc5c-f4bef8bf23a6 | 53629c27-7f2b-57dd-9eaf-eeb72d00ad8f | Matrices |
| 31ddb28a-8c1d-5808-bccc-f47d68f96c41, ae11aecb-8844-5bdf-9dec-7f21b4c25fad | a2f005b1-b3bd-5066-8916-9980e0cc6379 | Inequalities and absolute value |
| 3eff8a14-c778-5c68-b2d6-c4eda2007af4 | fbeeabb3-36f0-5a7d-bccf-ea9a8a5ab859 | Inequalities and absolute value |
| 6dc9e13a-f3bd-5f3a-a2cf-c9f11660f0cb, f452b8ea-1e95-5d3b-ada2-a4b7aa48a75e | 06c760a1-e61a-5109-9296-801757302007 | Inequalities and absolute value |
| 7e080c5c-2b38-577d-bc87-d25a193c5a3e | ec1fe096-170f-557c-9ae4-2047f109c798 | Functions and transformations |
| 7f8050b5-15b3-5463-8676-bbb0257a27ee | f3504d47-86ba-5207-97eb-37329e867c10 | Statistics and data analysis |
| 810b6716-8724-5d85-81c4-5006f1f97ef5 | f38c0869-5d24-5c03-8fc1-9c450d34fb4f | Quadratics and polynomials |
| 8bcc0c58-4a45-5c07-8295-5f9e8197a447 | d84343dd-dcb4-57cc-bd36-0d8b0b9cade5 | Exponents, radicals and growth |
| a085f287-90e7-5005-9f88-1f77549cb994 | ae5c13e3-84e1-58c7-9da5-5ec1d52e7525 | Exponents, radicals and growth |
| aacba8d8-0f1e-5a41-b7bc-f4b401e9bd24 | 9a0343f1-04dd-56e4-b6fc-a885ca0ae4f0 | Exponents, radicals and growth |
| af2c2124-569a-56d4-9b36-a22cf8f089cd | cefc1468-7880-55a1-9eb2-d84b876b5c60 | Systems of equations |
| ec6acdfa-1dab-561f-ab3a-fd7a542c2ea6 | ad96f85f-6241-54dd-8d5b-0d1d297676a9 | Systems of equations |

## Corrected existing content

| Question | Change |
|---|---|
| 08891f95-057c-59d1-9834-196b8872ba10 | Replace answer-sheet reference with an independently worked explanation. |
| 44bddf08-7b19-5222-acb5-5eaa9d5789d7 | Replace answer-sheet reference with an independently worked explanation. |
| 8b79f97d-7d46-5542-be2b-5083826a7317 | Replace answer-sheet reference with an independently worked explanation. |
| d65fd706-b296-58db-8f18-c0bd9a99ab0f | Remove unrelated cover artwork; preserve the answer and all attempt records. |
| ed362c08-1a82-5b56-be44-044737f550e7 | Remove unrelated cover artwork; preserve the answer and all attempt records.; The complete linear model is given in text. |
| ed76ef45-9030-5378-b804-4c4650a634ea | Replace answer-sheet reference with an independently worked explanation. |
| f071a174-ffa8-5c12-b7d7-45d4c9dec57f | Replace answer-sheet reference with an independently worked explanation. |
| 1c2d4b54-2316-57a1-95f4-b0539cfdeb89 | Remove unrelated cover artwork; preserve the answer and all attempt records. |
| 2574795c-0842-5799-a7a6-9f318be55de6 | Remove unrelated cover artwork; preserve the answer and all attempt records.; Explicit instructor diagram defines the two exterior angles and the requested angle; it is not claimed to be a recovered source image. |
| 38b3ea7c-1a64-5d12-8944-dedd2448b7c9 | Remove unrelated cover artwork; preserve the answer and all attempt records.; Explicit instructor clarification supplies the right angle and angle correspondence missing from the unrelated image. |
| 5b49ca69-bdf0-5859-b0c5-c8d1b68ccb9f | Remove unrelated cover artwork; preserve the answer and all attempt records. |
| b18f2a3d-941e-5ee7-92f4-f883d6c69473 | Remove unrelated cover artwork; preserve the answer and all attempt records. |
| c8750f4c-38d7-5dd7-885a-ebf5fef38bc6 | Remove unrelated cover artwork; preserve the answer and all attempt records. |
| df2132af-840a-501e-9268-3a64a7d75791 | Explicit instructor clarification adds the omitted 90° central angle. The existing accepted answer D is unchanged. |
