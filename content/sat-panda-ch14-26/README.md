# College Panda Chapters 14–26 SAT exercise intake

The pinned original PDF has SHA-256 `a6e7dcdb5eb34a88aff2163723015305c2700e26bdde7ce8e6242136a65593b8`. Chapter 27 is its answer section. The 380 numbered exercise panels in Chapters 14–26 were indexed by page and column and checked against every printed number badge. `reviewed-keys.json` transcribes the corresponding boxed answers from Chapter 27, with printed alternative fractions and decimals separated by `|`.

The source is scanned. Each bank question displays its complete original panel, including any graph, chart, table, equation, or multiple-choice options. Text labels identify the exact chapter, exercise, and number; they do not replace a mathematical expression with potentially faulty OCR. The scored choices are A–D when the boxed answer is a letter. Grid-ins preserve the printed valid forms. Worked-answer pages live in a private table and are returned only after an answer is checked in final revision.

`extract.py` regenerates `question-index.json` from the pinned scan. `build.py` builds one transactional SQL file per answer page, validates all 380 index/key pairs, attaches scanned panels, stores each private worked-answer page once, creates private scoring keys and active revision items, and rejects duplicate codes or exact normalized stems. Generated SQL stays outside the repository. Page transactions are independently retryable: deterministic IDs and equality checks prevent existing content from changing silently.

Run:

```sh
python3 content/sat-panda-ch14-26/extract.py ORIGINAL.pdf content/sat-panda-ch14-26/question-index.json
python3 content/sat-panda-ch14-26/build.py ORIGINAL.pdf /tmp/panda-import-sql
```

Audit checkpoints: 380 original badges in 22 exercises; 380 boxed keys; 48 private answer pages, including six pages where one exercise ends and another starts. Verify the live bank's question, key, figure, revision, fingerprint, and source-page counts after importing, and run an import again under rollback to check idempotency.
