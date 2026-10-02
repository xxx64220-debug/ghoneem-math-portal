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

## Isolated Chromium verification

The existing Playwright framework now runs `tests/browser/english.spec.cjs` at 1280×800 desktop and 390×844 touch-enabled mobile sizes. The fixture mirrors the observed import topology: one explicitly marked `assets.html` root, metadata divs, original paragraph nodes, bold numbered references, underline, highlight, line break, raster illustration and caption; `stem` remains separate. Fixture text and image are synthetic, so the suite does not certify production passage contents.

Eight added browser cases cover side-by-side desktop panes, paragraph spacing and readable line height, preserved formatting, decoded and bounded illustrations, stacked mobile panes with unrestricted passage height, pointer collapse and keyboard reopen, answer autosave, next/previous navigation, retained selection, submission and review. Each math track is also exercised with marked HTML and must retain its generic figure path in exam and review. The five jsdom regressions additionally compare math markup with the original renderer and verify uncertain boundaries and all practice routes.

```sh
npm ci --prefix tests/browser --ignore-scripts --no-audit --no-fund
cd tests/browser
npx playwright install --with-deps chromium
npm test
```

CI serves only local `web/` and mocks the SDK/API boundary; unknown remote requests fail. No browser request reaches production Supabase. Desktop/mobile screenshots are retained in the `browser-smoke-results` artifact for visual inspection. Browser emulation does not certify physical-phone touch behavior, actual enrolment, production submission/grading, deployed assets or CDN availability; those remain real-account/device checks. No question data, database changes, or passage-boundary inference is introduced.
