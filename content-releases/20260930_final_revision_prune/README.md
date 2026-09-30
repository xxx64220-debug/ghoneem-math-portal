# Final Revision representative catalogue — 30 September 2026

This classification-only release reduces the active Final Revision catalogue from 2,427 rows to 1,344 ready representatives: 456 SAT, 438 EST I, and 450 EST II.

The rule is deliberately conservative: retain at most two ready, unheld questions for each exact source track, lesson, normalized idea, and difficulty. Two representatives preserve question-level variation and retry value in **All**, while focused collections continue to select only one question per idea. Ranking prefers rows that cover more focused collections, then Unique, Must Know, Most Repeated, and a specific reviewed takeaway. A stable question-ID tie-break makes the result reproducible.

The release deactivates 1,070 excess representatives and 13 fingerprint-stale rows. It does not delete or rewrite any question. Every **ready pre-release** Must Know, Most Repeated, and Unique track/lesson/idea/difficulty slice remains represented. Stale-only slices are excluded from that comparison; see [the idea-loss audit](idea-loss-audit.md) for the three lost idea groups, an additional medium difficulty loss, and two lost Unique slices.

`apply.sql` is guarded by the exact active-catalogue metadata checksum, current source fingerprints, expected track and idea counts, an audit marker, timeouts, and transaction locks. It writes an item audit for every deactivation and refuses a rerun.

Question IDs, stems, choices, answer keys, explanations, assets, exam membership, historical revision snapshots, attempts, scores, daily progress, and notebook state are checksummed before and after the update. Only `revision_items.active` and `audit_log` change. Deactivation is reversible, but this release intentionally has no automatic rollback.

This is curation and classification only. It does not certify or recertify any mathematical answer.
