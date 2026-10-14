# Exact EST I source recovery — 5 October 2026

All 12 originals named by PR #26 are mapped to their exact recorded source PDFs and physical pages. `decisions.json` records the source identities, SHA-256 values, printed item context, independent mathematics and the outcome for each ID. Question suffixes such as q57 are extraction IDs, not printed question numbers.

Three proven transcription errors are restored in place:

| Original | Exact page | Repair | Eligibility |
| --- | --- | --- | --- |
| `92118004-2f60-6326-dab8-e6ad8b7911e7` | Revision 1 p31, printed Q15 | Restore the definition of A(x), four squared powers and worked explanation | Remains held as a duplicate of verified canonical `53c77113-7a68-6837-4af9-b5d4594962cb` |
| `dc220155-bbb4-ddc2-6f65-aa31fc55dd7a` | REVISION 2 June p14, printed item 8 | Restore y², four clean choices and exact calculation | Remains held: 400/9 is exact; printed 44.44 is approximate and source lacks rounding instruction. Existing adaptation supplies it explicitly. |
| `331de3d6-88c5-6cf4-3195-fd9efc2019d6` | Revision 1 p12, printed item 2 | Restore choice A from OCR 90.1 to printed 50.7 | Remains held: no printed choice equals 910/57 or its correct one-decimal rounding |

`02ac14b4-f84e-6e9f-1ab3-1427f41cdef7` is a source defect, not an OCR coordinate error: its exact August p36 printed Q35 says A(−3,44), giving −11.5, absent from choices. The clean June copy with A(−3,4) is corroboration of a different version; it does not authorize rewriting this original.

The six previously held full-subject June questions still reproduce their source defects: spinner fairness/independence, penalty independence, fake-die fairness, inconsistent pool units, an interest rate absent from choices and an incorrect weighted-mean choice set. The two previously verified duplicates on REVISION 2 p23 remain duplicates; their keys and prior clarification are preserved.

## Source identity and Drive limits

- Exact August source: recorded Library ID `libfile_ba20da2ba34c8191853fed03ef10e742`, `Revision 1_260823_150138.pdf`, 48 pages. Drive ID `1x_wqkBgv1qjLmnbJUThh5jz4-C028zNM` has the same filename and byte-identical embedded question images on pages 12, 31 and 36. The PDF wrapper bytes differ; both file hashes and exact image hashes are recorded.
- Exact June scan: recorded Library ID `libfile_ef9f0b1667b48191bd8143933b32d0f3`, `REVISION 2_260630_194855.pdf`, 46 pages. Source pages 14 and 23 are visually unambiguous. No matching Drive identity was located; `drive_file_id` is null, never fabricated.
- Exact full-subject revision: recorded Library ID `libfile_e3a383e888208191abcb57b2b4bcde0d`, `DOC-20260623-WA0016_260916_184619.pdf`, 56 pages. Pages 20, 22, 24, 38 and 43 were visually checked. Drive `1yl0GXISExsXpdnbEsMUCxXXeUq8R8gNu` is the differently dated `_260830_202952` edition and is recorded only as corroboration.
- Drive filename queries, the current teaching-source folder and the two plausible revision PDFs were checked. `revision_260726_203319.pdf` (29 pages) and `Revision _260831_221212.pdf` (28 pages) do not match the recorded June scan. The previously searched new-math PDF has no demonstrated alias mapping and was not used as authority.

No missing diagrams are invented. The recovered polynomial and inverse-proportion items are fully text-defined; the weighted-mean table is preserved in the stem and original asset. The June spinner/die/penalty pages contain no figures establishing the missing probability conditions.

## Apply, validation and rollback

`apply.sql` atomically guards the current question/content fingerprints for all 12 records, locks the question/key rows, refuses replay and records private before/after data in the existing administrator-only audit log. It changes only proven source text, explanations and evidence metadata. All 12 remain ineligible for new practice. Correct keys, IDs, track/lesson assignments, replacement links, figures, exams, assignment targets, revision memberships and all student history remain unchanged. No frontend publication is needed.

`rollback.sql` restores the exact pre-release text/assets/explanations and rejects later content changes or a repeated rollback. It never changes keys, assessments or student history. Application after rollback still requires a fresh packet.

Validation: `python3 tests/est_source_evidence_math.py` and `PGLITE_MODULE=<local pglite path> node tests/est_source_evidence_db.cjs`. Tests cover exact/approximate answers, unique polynomial solution, the source coordinate, duplicate counts, all 12 records, atomic late-record conflict rejection, replay refusal, rollback conflict rejection, all holds and preservation of keys, assessments/audiences/history/revision membership. Tests never connect to production.

Exact Drive provenance for the two June originals remains unavailable. Exact recorded Library provenance is recovered and is sufficient to identify their source pages; no substitute file is passed off as the import source.
