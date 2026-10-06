# College Panda Chapter 12: Quadratic Equations

Exercise 1 has 16 questions and Exercise 2 has 18. All 34 are in `questions.json`, with checked answers and explanations. `make_manifest.py` regenerates the manifest from the independently transcribed source. Every question has a crop of the scanned original. Source questions are on PDF pages 140–144; the printed worked answers are on PDF pages 355–358.

The builder checks the pinned source PDF SHA-256, duplicate source IDs and normalized stems, then adds the questions, private keys and Final Revision items in a transaction. It accepts an optional batch index 0–6 for small transactions of five questions (the last has four):

```sh
python3 content/sat-panda-ch12/make_manifest.py
python3 content/sat-panda-ch12/build.py '-SAT-Math-Panda_260828_142145.pdf' /tmp/panda-ch12.sql
python3 content/sat-panda-ch12/build.py '-SAT-Math-Panda_260828_142145.pdf' /tmp/panda-ch12-0.sql 0
```

Production release was performed in seven batches after a rollback dry run. Readback: 34 questions, 34 keys, 34 source images, 34 Final Revision links, 34 correct source pages and chapter tags, and 34 matching revision fingerprints. A preflight comparison found no matching source codes or exact normalized stems in the existing SAT bank. Chapter 12 brings the live SAT bank to 1,515 questions.
