# Repository synchronization — 30 October 2026

The GitHub application source has been reconciled with deployed Site version 131,
hosted source commit `5549ec3f488f318f23c223100e737ff8799d62a7`.
The Sites deployment was confirmed successful. This is a repository update;
it does not publish another Site version or execute production SQL.

## Recovered application source

- Group-specific Daily Quiz selection, scores, streaks and safe group switching.
- ACT2 course references, source-PDF browsing and question-bank navigation.
- Collapsed lesson-exam and quiz browsing, display-only assessment catalogs,
  search, pagination, and preserved start/resume/review access checks.
- Full SAT review across both modules and source-paper question counts.
- Shared diagnosis evidence, explicit class selection and visible test accounts.
- The mobile/tablet layout and search-performance changes in
  [RESPONSIVENESS_2026-10-30.md](../RESPONSIVENESS_2026-10-30.md).

The corresponding `web/` and `dist/` application files match. PR #35 was merged
separately to record the previously deployed owner-authorized Desmos configuration.
GitHub's newer registration queue validation, notification retry limits,
trusted-browser controls, assignment tests and cross-browser fixture helper were
preserved.

## Backend provenance

The Daily Quiz Edge Function matches deployed version 6 byte-for-byte after
trimming trailing whitespace. Read-only production inspection confirmed the
group-quiz RPCs, staff diagnosis, batch diagnosis, ACT2 collection search and
module/full-exam review routines exist.

Eight missing SQL support files were recovered from the same hosted source.
They are historical implementation records, **not a migration plan**. In
particular, `daily_group_scores.sql` contains one-time table changes. Do not
replay these files on production or replace newer routine definitions without
fresh database comparison. The current registration and notification fixes
remain authoritative where the hosted snapshot is older.

## Validation

The local application regression selection covers 248 tests. Three stale
fixtures were repaired: the extracted English-review harness now includes
`reviewBody`, ACT2 distinguishes the original 19 core lesson sets from the
55 current sets, and served-file checks support this repository's `dist/`.
The failed suites passed after those fixture changes.

All 30 selected security, response-header, authentication and device tests
passed. Calculator and ACT2 source-link checks also passed. The public-artifact
credential scanner passed. Newly recovered behavior is included in GitHub CI.
Browser fixtures now provide scoped diagnosis data and choose a class explicitly,
while retaining trusted-browser and WebKit protections.

DOM checks are not physical-device validation. GitHub CI provides the repository's
browser and disposable-database checks; inspect the pull request checks for their
final results.

## Remaining repository boundary

The two Git histories remain separate. GitHub is not a complete export of the
hosted build or live database. The hosted snapshot contains 563 additional PNG
assets and 949 encrypted archive files, totaling 138,370,797 bytes, absent from
this checkout. They remain available in the existing hosted source; this update
does not duplicate that archive or export private decryption data, student
records, live answer keys or production credentials.

Use the existing Sites source and project for future deployments. Do not replace
it wholesale with this GitHub checkout or replay question imports. Reconcile
changes against the latest source first so concurrent portal work is preserved.
