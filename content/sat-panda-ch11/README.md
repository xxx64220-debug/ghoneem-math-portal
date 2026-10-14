# College Panda Chapter 11: Word Problems

Both exercise sets contain 17 questions, for 34 total. `questions.json` is an independently checked transcription from the scanned workbook; `make_manifest.py` regenerates it. The printed worked answers are on PDF pages 350–354, and the questions are on PDF pages 130–135. Every item includes a page-specific crop, with the segment diagram in Exercise 2 Question 9.

The 34 source IDs were already released before this branch update. A live readback found 34 questions, 34 private answer keys matching the printed solutions, 34 source figures, and 34 Final Revision links. `build.py` can import this independently checked manifest into an empty bank. If the IDs are already present, it checks the source code, page, answer, choice count, figure, and explanation before leaving the released wording and images intact. The live wording is slightly different from this independent transcription.

Rebuild the manifest and SQL from the original file:

```sh
python3 content/sat-panda-ch11/make_manifest.py
python3 content/sat-panda-ch11/build.py '-SAT-Math-Panda_260828_142145.pdf' /tmp/panda-ch11.sql
```

The source PDF checksum is pinned in `build.py`. Do not publish the generated SQL without checking the transaction against the target database first. The existing Chapter 6–11 `source_chapter` metadata typo is repaired by `repair-source-chapters.sql`, with a count guard and matching Final Revision fingerprints.
