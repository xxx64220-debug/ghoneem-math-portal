# College Panda Chapter 13: Systems of Equations

The two exercise sets contain 22 questions each. All 44 are in `questions.json`, with checked answers, explanations, source page references, and complete source crops. `make_manifest.py` regenerates the reviewed transcription. The source questions are on PDF pages 152–159 and the printed worked answers on PDF pages 359–364.

Graph questions include the full plotted lines and labeled choices. Several systems have infinitely many or no solutions; the explanations distinguish those cases from a single intersection. Exercise 2 Question 9 has answer 12, confirmed against its printed worked solution; OCR can misread the adjacent 32 in the equation as the answer.

The builder pins the PDF checksum, checks duplicate source codes and normalized stems, and writes a transactional SQL release with private keys and Final Revision links. Optional batch indices 0–8 create batches of five questions, except the final batch of four:

```sh
python3 content/sat-panda-ch13/make_manifest.py
python3 content/sat-panda-ch13/build.py '-SAT-Math-Panda_260828_142145.pdf' /tmp/panda-ch13.sql
python3 content/sat-panda-ch13/build.py '-SAT-Math-Panda_260828_142145.pdf' /tmp/panda-ch13-0.sql 0
```

The release passed a rollback dry run and was imported in nine transactions. Live readback: 44 questions, 44 private keys matching the manifest, 44 source images and page references, 44 Final Revision links, and 44 matching fingerprints. The SAT bank now has 1,559 questions.
