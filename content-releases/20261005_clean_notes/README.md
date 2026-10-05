# Clean source reconciliation: EST I notes, 5 October 2026

The cleaner 12-page upload contains the same 20 candidates as the earlier notes. Review records the exact file identity, SHA-256, page/block evidence and original Figure 8 crop. No official EST provenance or printed source answer key is asserted.

## Result

12 distinct complete source items are mathematically verified. Six are equivalent to older complete bank records; two remain held (triangle OPB has missing choices/response specification; the scoring question lacks the all-50-answered condition). Different numbers/context in a chained-ratio question are a repeated skill, not an exact source-equivalent duplicate.

The earlier import completed while this review ran, inserting 14 records. This packet reconciles those existing IDs, holds four newly imported equivalents (linear table, unknown-coordinate line, Julia balance, circle parameter), preserves all their keys and histories, fixes literal newline text, replaces the quadratic table with a native math array, and attaches the authentic supplied rectangle diagram. It adds only the two missing valid items: exponent approximation and chained ratios. Together, the two releases yield 12 distinct new eligible questions. The other two duplicates were already skipped.

The exponent's two real roots are approximately -0.963135087 and 2.211478586. Only B (-0.96) is a matching listed approximation. The prompt explicitly says approximates a real solution; the original equation and all choices remain unchanged, and the clarification is documented. The chained-ratio answer is A (3:10); C (6:15) equals 2:5, so there is no duplicate correct option.

## Release safety and validation

The atomic SQL guards the full current EST I snapshot using per-record digests, refuses replay, verifies all 14 before-record hashes, and refuses to alter any imported record that has since entered an assessment or curated revision. Original source metadata remains; the cleaner file is added as corroborating evidence. A keyless audit backs up changed question text/assets. Every existing answer key and unrelated question stays unchanged. Exams, assignments, revision membership, attempts, responses and scores are untouched. No frontend deployment is needed: the original figure is an embedded PNG.

The first attempted insert packet timed out during its preservation assertion and fully rolled back (zero inserted rows or audit entries). It was discarded after observing the concurrent earlier import; do not attempt to reproduce that superseded insertion.

Offline mathematical checks solve all twelve eligible source items and both held items. Disposable PGlite regression checks reconciliation, two inserts, four duplicate holds, key/identity preservation, replay/stale-bank refusal, duplicate prevention, late-failure atomicity and refusal after assessment use. The fixture hash substitution never contacts production.

Live rollout completed on 5 October 2026 in the existing production project. Readback confirms 16 preserved/reconciled batch records: 12 eligible, four duplicate-held, 14 corroborated by the clean source and two newly completed. Literal newline count is zero. Both new keys (B and A) and the clean source SHA-256 were individually read back. The transaction asserted every original key unchanged and every unrelated question/key preserved. Do not replay the SQL.
