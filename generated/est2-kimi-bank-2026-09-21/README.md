# EST II Kimi question-bank release

Generated from the user-supplied `Kimi_Agent_Math PDF Question Bank(4).zip`.

- 1,127 unique EST II questions: 853 multiple-choice and 274 numeric-response
- 1,102 EST I-overlap questions, with a normalized-stem duplicate guard
- 230 questions with preserved graph, diagram, or table assets
- 10 curriculum lesson practices, 10 quizzes, and 5 full exams
- Every published assessment contains exactly 40 questions and uses a 3,600-second timer
- Known duplicates and source items explicitly marked ambiguous/review-required are excluded

`import_report.json` is the machine-readable release manifest. The SQL batches are
idempotent: question and assessment IDs are UUIDv5 values derived from stable source IDs.

Regenerate with:

```bash
python3 scripts/build_est2_import.py \
  --bank /path/to/_bank_backup \
  --figures /path/to/figures \
  --out generated/est2-kimi-bank-2026-09-21 \
  --asset-base https://raw.githubusercontent.com/xxx64220-debug/ghoneem-math-portal/main/assets/question-bank
```
