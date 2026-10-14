# September SAT source recovery, 29 September 2026

The original 27-page SAT Valley September PDF (SHA-256 `4a9e4676c5588802d579110119ab125bf5980a71bc103a960231722a641d05ee`) was inspected again at full page resolution. Its final worked-solution and answer-key pages confirm two questions that the earlier intake held:

- Q19, PDF page 19 (printed page 22): the complete angle diagram and all labels are present in the original. Parallel-line angle chasing gives $y=73°$ and $z=|127°-w|<73°$ when $54°<w<180°$, so the key is **B**.
- Q24, PDF page 24 (printed page 27): the defining equation is visible above the prompt. Since $|397-13|=|-371-13|=384$, $a=b$ and the numeric answer is **414**.

Both questions include a legible original crop, checked explanation, private answer key, and SAT Final Revision link. `questions.json` records the accessible transcription and `build.py` regenerates source images and guarded SQL from the pinned PDF. The generated SQL and the supplied PDF stay outside git. Run `python3 content/sat-sep-held-2026-09-29/build.py ORIGINAL.pdf OUTPUT.sql` to reproduce it.

The SQL passed a rollback dry run, was released to the existing portal, and passed a post-release idempotency rollback. Production readback found 23/24 September questions, two new source images, two private keys, two active revision entries with matching fingerprints, and 1,941 SAT questions overall. MCQ B and numeric 414 scoring were checked in the live database.

September Q18 remains held: its printed $6x^4+35x+11$ contradicts the even-power factorization and worked solution, which silently uses $35x^2$. Do not replace the original term with a guessed correction.

The other supplied SAT packets were audited as follows: Elite May 44/44; March International 40/44 (four held); March US 38/44 (six held); August International II 43/44 already in the bank (the remaining polynomial has remainder $-52$, absent from every choice); August Prediction 44/44, MSET008 50/50, and the College Board-style packet's 120 detectable IDs already present. College Panda Chapters 1–26 contribute 878 exercises; Chapter 27 contains worked answers. The March holds and their exact defects are documented in their packet READMEs. These 12 source-defective or response-format cases across the packets remain out of automatic grading pending corrected originals or a separately labeled revised practice question.
