# EST English reading layout

Read-only inspection of the existing portal database on 2026-10-01 UTC found 340 `est_eng` questions. All carry a single `<div class="est-passage">` in `assets.html`; `stem` contains the separate question. `assets.passage_title`, `passage_author`, `passage_number`, `module`, source identifiers and `lesson_type` describe shared passages. Lesson types include whole-passage, in-passage and underlined questions. There is no need to infer passage boundaries from text. Fifty-six records contain illustrations. The observed passage tags are div, p, b, u, mark, figure, img and figcaption.

The English renderer accepts only the marked single-root HTML container and only on `est_eng`. Unmarked or ambiguous HTML retains the existing renderer. Source text, paragraph boundaries, question IDs, assets and database contents are unchanged. Underlining, numbered references, highlights, captions and safe HTTPS/base64 raster illustrations survive the passage-specific sanitizer; executable tags, inline styles and event attributes do not.

Exams, answer review, daily quizzes, weak-topic drills and the mistake notebook share the layout. Desktop widths above 850px place the passage beside the question, with bounded passage scrolling. Smaller screens stack the passage above the question with no internal scroll limit. Native details/summary provides keyboard-accessible collapse and starts expanded. The 65-character line limit and paragraph spacing improve reading without reflowing source paragraphs or guessing paragraph numbering.

SAT, EST I Math and EST II Math remain on the original rendering path. The math exam regression compares production markup with the pre-change renderer from commit 2c239765. Deployed copies in dist match web.

Validation:

```sh
npm ci --prefix tests/english-runtime --ignore-scripts --no-audit --no-fund
node --test tests/english_reading.test.cjs
```

Five new tests pass, alongside all 40 checks in the existing JavaScript CI suite. Tests cover source-shape handling, paragraphs, underlines, highlights, illustrations, unsafe markup, answer selection, collapse state, all reading routes, uncertain boundaries, math exam parity and dist synchronization. CI installs a pinned, locked jsdom test dependency only; the client gains no dependency.

Visual browser QA remains pending: this environment has no Chromium executable and the browser download failed. Before deployment, check an illustrated and an underlined English question at desktop and phone widths, collapse/reopen the passage with touch and keyboard, select an answer, navigate, and review it. These checks require no production database changes. No deployment was performed as part of this change.
