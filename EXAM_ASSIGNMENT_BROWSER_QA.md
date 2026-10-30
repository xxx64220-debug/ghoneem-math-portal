# Assignment browser regression coverage — 30 October 2026

The assignment picker now has full-browser tests in addition to its existing JSDOM and isolated database checks. These load the real instructor page, styles, dialog, assignment writer and group/bulk entry functions. All backend requests are intercepted; unknown requests fail closed. The fixture contains 1,105 eligible synthetic students, overlapping groups, another track, a suspended account, existing expired assignments and controlled network failures. The new device controls receive a synthetic approved staff-browser response.

## Confirmed defect and correction

A failed assignment to a student with a long unbroken name caused horizontal overflow: Chromium measured 1,594 pixels of scrollable content in a 758-pixel dialog. This occurred with both the repository and deployed stylesheet cascades. [Reproduction run](https://github.com/xxx64220-debug/ghoneem-math-portal/actions/runs/41067989364).

The assignment stylesheet now wraps sibling alert messages and preserves their line breaks. This applies to single-exam, group-entry and bulk assignment errors. The only application changes are this CSS rule and the stylesheet version in the admin loader, with distributed copies kept identical. Saving, authorization, dates, exam records, attempts and scores are unchanged.

## Browser matrix

Each of the eight scenarios runs against both the repository layout and the deployed layout: 144 cases in total, without retries hiding failures.

| Engine | Viewports | Touch emulation |
| --- | --- | --- |
| Chromium | 1280×800, 820×1180, 390×844, 320×568, 844×390 | Tablet and phone sizes |
| Firefox | 1280×800, 390×844 | No |
| WebKit | 1280×800, 390×844 | Phone size |

Scenarios cover:

- Student name/email search, no results, search-only selection, hidden selection persistence, select-all and clear controls.
- Mixed groups and individuals, overlapping membership and one unique-recipient row per student.
- Roster pagination beyond 1,000, long names/emails, scrolling within student/review lists, dialog bounds and reachable date/action controls.
- Empty selections, invalid date order, Cairo-local dates, blank self-paced windows and preservation of existing expired assignments.
- In-flight control locking, repeated keyboard submission, Escape, partial failure and retry without repeating successful writes.
- Lost response readback, unavailable readback followed by a uniqueness conflict, and no duplicate synthetic assignments.
- Instructor scope, preselected group entry, individual-only selection and exam choice.
- Bulk retry retaining both completed exams and successful targets within a failed exam.

## Source parity and test boundaries

At the start, Site 123 was the latest deployed source (`3694f9600f41d45accb1bf3929de310f81661419`). Its inline admin CSS, dialog/field/assignment functions, shared assignment JavaScript/CSS and bulk code matched GitHub main. The GroupManager assignment function also matched; unrelated group test-account labels differed. Two additional production stylesheets are preserved with SHA-256 provenance in `tests/browser/assignment-deployed-layout.json` and inserted in their original cascade position for the deployed-layout tests.

During this audit PR #44 and Site 126 landed. The current source was reconciled before the fix; its device stylesheet and approval flow are retained. The assignment code and the two captured production stylesheets did not change in that release. This work does not replay Site 122 or any database release.

The fixtures substitute the SDK and CDN font/math resources. WebKit upgrades even loopback HTTP assets when `upgrade-insecure-requests` is present, so this directive is removed only from the isolated HTTP fixture's document and response header. Other response protections remain; production security policy is untouched. Existing response-header and security regressions continue separately.

Run from `tests/browser`:

```sh
npm ci --ignore-scripts --no-audit --no-fund
npx playwright install --with-deps chromium firefox webkit
npx playwright test --config playwright.assignments.config.cjs
```

[Assignment browser CI](https://github.com/xxx64220-debug/ghoneem-math-portal/actions/workflows/assignment-browser.yml) retains screenshots and failure traces for 14 days. The original SAT/EST browser suite remains separate.

## Verification limits

The supported cloud preview service became healthy, but its cloud-browser route returned `ERR_CONNECTION_REFUSED`. Browser evidence therefore comes from GitHub Actions' real headless engines and their screenshots, not a live signed-in production session.

Physical Android/iPhone/iPad devices, branded Safari on macOS/iOS, Firefox on physical devices, native date-picker popovers, virtual keyboards, pinch zoom, PWA behavior and assistive-technology behavior remain unverified. Playwright WebKit is not branded Safari; viewport/touch emulation is not physical-device testing. Backend failure simulations verify client behavior and do not replace the existing authorization/database tests.
