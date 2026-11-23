# Full-exam grid validation — final status, 23 November 2026

**Release assessment: keep PR #68 in draft. The reviewed fixes are implemented, but the current production candidate is not ready to merge or deploy.** No merge or production deployment was performed by this validation task.

## What is live

Sites confirms successful production deployment of **v209**, source `208587d8b32dfb27242ea74e9b00145caf73c197`, at https://math.portal.ghoneem.com. The v209 deployment ID is `appgdep_6b02db1b2514819187cc49d733e35e80`.

The live interface already has a responsive full-exam grid, paired SAT modules, natural title ordering and priority for in-progress work within each grid. This feature therefore is not wholly new in PR #68. Live also contains newer access, runner and other frontend changes absent from the PR's older base. Replacing production with the PR's complete HTML files would discard those changes.

The latest public-source audit (2026-11-23T05:53:25.107Z) confirms that the live grid **does not contain the reviewed corrections below**. Its two relevant renderer blocks exactly match the original reviewed v205 blocks. Grid styles have moved into `daily-challenge.css`; that stylesheet changed, while the other 12 linked reviewed stylesheets match.

## Concrete defects and draft corrections

| Finding | Correction |
| --- | --- |
| The inherited mobile row rule gives a tile's copy a 100% flex basis; short single-exam cards become unnecessarily tall. | A grid-scoped `flex-basis:auto!important` override. A 360px fixture improved from 283×335px to 283×283px. Cards with long content can grow vertically rather than clip. |
| Unpaired SAT modules are appended after sorting, so an in-progress unpaired module can appear behind ordinary single exams. | Re-sort the final singles array with the shared in-progress/natural-title comparator. SAT pairs stay together. Priority remains within each grid. |
| Repeated Start/Resume/Review labels lack an exam-specific accessible name. | Include the visible action plus exam/module title in `aria-label`, retaining labels, button elements and handler targets. |
| Both modules submitted with a pending score are labelled Incomplete. | Show Awaiting grading; calculate the combined score only when both scores exist. |
| Original PR cards are narrower and less consistent with the already-live layout. | Align the PR's sizing/margins with the reviewed live grid. The v209 patch retains current live sizing and styles. |

The current-source patch changes only the two reviewed renderer regions plus the scoped CSS override. All code from `wireDashboard()` onward, including runner, timer, submission and review, remains byte-for-byte unchanged. The patch does not change database data or access policy.

## Evidence and limits

| Evidence | Result | Scope |
| --- | --- | --- |
| Real Chromium rendering | 64 layout cases across 360, 390, 768 and 1280 CSS-pixel widths | Original PR, fixed PR, v205 live snapshot and v205 overlay × SAT/EST I/EST II/ACT II. Exact renderers and styles; synthetic records in sized iframes. |
| Layout measurements | No measured page horizontal overflow, card-child bounds violations or card buttons below 44×44px | The browser fixture matrix above; not a physical-device touch test. Long headings wrap and cards may grow. |
| Keyboard interaction | Tab order, disabled-control skipping, visible 2px focus outline, Enter Resume and Space retake checked | Browser fixtures; intercepted actions verified IDs and untimed=false. Not a screen-reader audit. |
| Original Sites integration | 79 focused tests and 24 access/control comparisons passed; production build succeeded | Saved v206 built from exact v205 source. 5,020 packaged assets; 240 local links, none broken. This candidate is now obsolete. |
| Current v209 overlay | Ten meaningful grid behavior tests and 24 access/control comparisons passed | Node/JSDOM simulations, not browser rendering. The source/dist mirror test does not apply to an external HTML overlay and is explicitly skipped in subsequent runs. |
| Existing GitHub checks | See PR checks and audit run linked below | Separate from current-source browser approval. |
| Authenticated exam cycle | Not verified | Secure sign-in was cancelled. No real start, saved-answer/resume, module completion or review cycle was completed in production. |

Corrected v205 browser fixture column counts:

| Width | Paired SAT cards | Single-exam cards |
| --- | ---: | ---: |
| 360px | 1 | 1 |
| 390px | 1 | 2 |
| 768px | 2 | 3 |
| 1280px | 3 | 5 |

These counts are observed browser results for the reviewed v205 overlay. **They are not a fresh browser pass for v209's changed CSS.** Physical mobile devices and focused Firefox/WebKit grid checks remain unverified.

The simulated access matrix preserves allowed/disabled controls, target IDs, open/closed/content-review states, retake and review behavior, and in-progress can-finish access. Module 2 locking/unlocking was exercised using synthetic state transitions. This supports preservation of the existing controls, but does not establish server-side persistence or scoring.

## Loading performance

The browser fixture's normal redraw medians were approximately 7.5ms for reviewed live and 8.8ms for its patch; the small difference is noisy and is not a claimed improvement. A stress fixture of 311 cards/619 records took roughly 0.6 seconds per redraw. This is a large-list responsiveness risk, not a verified normal student delay.

Read-only assignment aggregates showed maximum assigned catalogues of SAT 44 cards/87 module records, EST I 47 cards, EST II 54 cards, ACT II 33 cards and EST English 12 cards, before access filtering. No personal records were included in this report. Authenticated list/network latency and mobile-device performance remain unmeasured. The public HTML audit fetch timing is not an application-load benchmark.

## Saved deliverables and exact provenance

- [PR #68](https://github.com/xxx64220-debug/ghoneem-math-portal/pull/68), branch `ui/full-exam-card-grid`, remains open and draft.
- [Current v209 draft patch](live-v209-grid.patch). Apply only after comparing the source to the audited public response; never overwrite the entire newer frontend with the old PR.
- [Current public-source audit](live-v209-audit.json).
- [Audit and simulated regression run](https://github.com/xxx64220-debug/ghoneem-math-portal/actions/runs/45120562383).
- [Public HTML, patched HTML and patch artifact](https://github.com/xxx64220-debug/ghoneem-math-portal/actions/runs/45120562383/artifacts/14793686482) (GitHub artifact retention: 30 days).
- [Original report and browser evidence](README.md); its earlier release/packaging status is superseded by this document.

Audited public HTML SHA-256: `0e79bcc9ae50166caf13ea13b3a53a2b81980f782ee3ddbb13f9797066da368e`.
Proposed patched public HTML SHA-256: `dbb1d62222a394c4fed5def29851bd12db492af552fe2b699b27471f0c1c2c3b`.
These identify the fetched responses, not the full Sites source tree or a saved release.

Saved **v206** (`cf92ac7ba19f55996b16b4a6985f8f0d9a177b57`) contains the previously browser-tested v205 overlay and passed its build. **Do not deploy it over v209.** It was saved without deployment. The current v209 patch has not been integrated into and built as a new Sites version because the execution environment failed after the production version changed.

## Remaining release work and approval boundary

1. Integrate the narrow patch into the exact current Sites source, keeping its mirrored frontend files consistent. Recheck the deployed version before preparing the build.
2. Repeat the four-width browser matrix against that resulting build and current complete stylesheet cascade.
3. Complete a dedicated test-account cycle: list load, start, answer persistence, resume, timer behavior, submit, SAT Module 2 unlock, full review and permitted retake. Do not use a student's live attempt.
4. Run the relevant regressions and production build, save the resulting version without deploying, and identify its exact source/version.
5. Present the resulting merge and/or production release for **explicit owner approval before either action**.

There is no approved merge or deploy command. Merging this older-base PR and deploying v206 are not recommended. The safe proposal is to carry only the reviewed corrections onto the current source and finish the outstanding verification first.
