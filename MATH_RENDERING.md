# Readable currency and mathematics

The student and instructor pages load `web/portal-math.js`. Student exams,
reviews, daily quizzes, notebooks, drills, staff bank previews and teaching mode
use this adapter. Do not call KaTeX auto-render directly from these views.

Bare dollar signs in prices must stay literal. Previously, auto-render paired
the dollar signs in `$75. An English book ... $153` and interpreted the sentence
as TeX. Spaces disappeared, words became italic variables, and the percent sign
could hide the remainder of the sentence.

The shared renderer converts unambiguous legacy `$...$` formulas to `\(...\)`.
It then enables only explicit `\(...\)`, `\[...\]` and `$$...$$` delimiters in
KaTeX. Ordinary prose between dollar signs and dollar signs starting another
amount stay plain text. Ambiguous legacy text stays readable rather than being
typeset as a guessed formula. New imports should use explicit delimiters for
mathematics and ordinary `$75` for prices; no question-bank rewrite is needed.

Normalization changes DOM text only. It does not insert HTML, change source
questions, choices, keys, assignment data or historical results. Explicit TeX
commands, matrices, existing KaTeX output, code and SVG are preserved. KaTeX
retains `trust:false`, `maxExpand:1000` and `maxSize:20`.

`tests/portal_math.test.cjs` uses real KaTeX with a DOM to cover the reported
PSD 133:Q24 text, multiple prices, decimals, escaped currency, mixed formulas,
tables, all three math tracks, reviews, practice and instructor answer reveal.
It also prevents new page-specific calls that bypass the shared renderer. CI
runs these tests after installing the pinned `tests/english-runtime` packages.

Run locally with:

```sh
node --test tests/portal_math.test.cjs tests/exam_builder.test.cjs tests/practice_figures.test.cjs
```

The [24 October browser audit](docs/MATH_RENDERING_VISUAL_AUDIT_20261024.md)
checks actual exam/review layouts at desktop, tablet and mobile widths with real
KaTeX fonts. `web/portal-math-layout.css` prevents fraction/radical glyphs from
being clipped by scrollable question and answer containers. The focused
`tests/browser/math-rendering.spec.cjs` suite covers glyph bounds, currency,
matrices, tables, diagrams and navigation state. See the audit for reproduction
and physical-device verification limits.
