# Mathematics rendering visual audit — 24 October 2026

The current production source (Site version 115, source commit
`4267c2d6394f6bcc2c3c3b67a3d0deff529a171a`) retains PR #40's currency-safe
renderer. A browser audit found a separate CSS defect: mathematical choices
could acquire tiny vertical scrollbars and clip denominator glyphs. For example,
the bank matrix question `b81f9c48-ec9f-59d0-a21e-d65547b86a1e` rendered fraction
choices into 28px-high containers with 33px scroll heights. Its denominator
glyphs extended about 3px below the visible container.

`portal-math-layout.css` reserves vertical space only for containers containing
rendered mathematics. Both student and instructor documents load it. The shared
currency normalization adapter, bank content, answer keys, scoring, saved-state
handlers, backend configuration and domain are unchanged.

## Browser verification

Cloud Chromium loaded the actual current student examination and review
documents with isolated API/SDK fixtures, real KaTeX 0.18.2 CSS and local KaTeX
fonts. The local audit also loads the production Google typography stylesheet.
No real account, student attempt, assignment or database write was used. The live
production landing page was inspected and required sign-in; authenticated
production exam sessions were not directly inspected.

| Coverage | Cases |
|---|---|
| Tracks | SAT, EST I, EST II |
| Frame viewport widths | 1280, 820, 390, 320px |
| Surfaces | Actual examination and review renderers |
| Content | Reported $75/$153/40% prose; mixed legacy/explicit formulas; bank matrix and fraction choices; long inline expression in a stem and choice; wide display matrix; table with prices/percentages; bank SVG diagram; nested fraction/radical with grid input |
| State | MCQ selection, flag, grid input, recorded fixture saves, timer progression through question navigation |

The matrix and diagram are copied from checked-in reviewed bank records, with
source paths retained in the fixture JSON. Other questions are explicitly
synthetic layout stress cases. Repeating these fixtures across tracks tests
rendering, not curriculum eligibility or question-bank accuracy.

The final browser run covers 204 combinations: 192 question/surface/track/width
checks and 12 navigation/state checks. All pass. Before the CSS correction, the
stricter glyph-boundary checks reproduced 60 failing combinations. Basic page
overflow checks alone had missed this defect; the added coverage checks actual
glyph bounds and unintended vertical scrolling. Wide tables/matrices remain
readable through their existing local horizontal scroll areas without making
the whole page overflow. Classic browser scrollbars can reduce content widths
by 15px; the assertions use the actual document client width.

[Recorded browser results](math-rendering-audit-20261024/results.json) and
[corrected mobile matrix screenshot](math-rendering-audit-20261024/mobile-matrix.jpg)
are retained with the source. KaTeX and Inter font loading were confirmed.

The focused existing rendering, exam-builder, practice, client-state, flag and
SAT full-review regression suites passed all 26 checks. The production build
passed. The new Playwright suite loads real pinned KaTeX, emits screenshots and
JSON results, and is included in the existing desktop/tablet/mobile CI job, with
additional 320px cases. GitHub CI results are separate from the cloud-browser
audit; see the linked PR for their final status.

## Reproduction

```sh
npm ci --prefix tests/english-runtime --ignore-scripts --no-audit --no-fund
node tests/browser/prepare-math-audit.cjs /workspace/scratch/math-audit-preview
sites-preview start /workspace/scratch/math-audit-preview
```

Open the returned preview URL and choose **Run all viewport checks**. The
generated directory is test-only and must never be published or placed inside
`portal-static`. It rewrites CDN URLs to local pinned KaTeX and a fixture SDK,
and removes local-only cross-origin/SRI and insecure-request-upgrade obstacles;
production HTML security settings stay intact. The local HTTP fixture supplies
a synthetic UUID implementation for activity events. Unknown fixture API calls
fail closed. The Playwright route fixture retains production security headers.

```sh
npm ci --prefix tests/browser --ignore-scripts --no-audit --no-fund
cd tests/browser
npx playwright test math-rendering.spec.cjs
```

## Verification limits

Viewport verification is automated browser testing, not testing on a physical
phone or tablet. Android/iOS browser chrome, virtual keyboards, pinch zoom, touch
scrolling, safe-area behavior, PWA installation, Safari and Firefox have not
been directly verified. The Playwright CI fixtures use system UI fonts for
reproducibility; the interactive audit also loads the production typography.
This audit verifies the listed representative cases, not every bank record or
the correctness of scoring/calculator services.
