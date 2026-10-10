# Elite Practice X6 May Edition, math modules

The two math modules contain 44 distinct questions. All 44 are in `questions.json`, independently answered against the original page images and checked against the printed answer sheet. Nine graph, diagram, or table screenshots are embedded in the generated release for questions that require a visual. One question spans PDF pages 97–98; its full visual is assembled from both pages. The answer sheet is PDF page 100.

Build a transactional import with:

```sh
python3 content/sat-elite-may-2026/build.py 'ElitePracticeX6 (May Edition) @EliteXSAT_260605_182638.pdf' /tmp/elite-may-release.sql
```

The source PDF SHA-256 is pinned in `build.py`; the script validates it and writes raw image hashes to `image-hashes.json`. The release adds 44 `sat` questions, 44 answer keys, and 44 Final Revision items. Generated SQL embeds image data and is kept out of git.

## Review note

Module 2 Question 21 asks for the effect of removing the point (0,12) from a quadratic fit; its two-page source graph is retained. Explanations are concise and do not include the full original page text.
