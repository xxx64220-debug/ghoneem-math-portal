# Second SAT and EST II revision idea expansion — 30 September 2026

This additive release places 40 more already verified SAT questions and 40 more already verified EST II questions into Final Revision. Every selected question represents a distinct, question-specific idea absent from its own track and lesson at preflight.

The semantic audit deliberately excludes over-broad classifications, including EST II ellipse and conic questions filed under general functions. It also excludes held questions, source-key-only explanations, duplicate question content, existing revision questions, and exact idea collisions. SAT rows receive only the `sat` programme and EST II rows receive only the `est2` programme. EST I is unchanged.

`apply.sql` is a one-time guarded data release. It refuses to run if the release audit exists, the revision catalogue changed, any source fingerprint differs, a question is no longer verified and unheld, track or lesson classification differs, content already appears in Final Revision, or an idea already exists in the same track and lesson.

This is revision classification and curation only. It preserves question IDs, stems, choices, answer keys, explanations, assets, exams, sessions, and scores. Existing verification metadata is required, but this release does not claim a new mathematical answer certification.


