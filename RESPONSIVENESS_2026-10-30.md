# Portal responsiveness and display performance — 30 October 2026

Based on hosted source commit 896e7d3c1b9556f93e9c969d7494af85e5df890b, preserving the newer hosted features that are absent from the GitHub main copy.

## Changes

- Student and instructor section selectors use a label row, with stacked actions at widths up to 400 px.
- Tablet mastheads and exam toolbars wrap through 900 px; the exam toolbar uses the correct sticky offset after the masthead stops sticking. Empty mobile header spacers no longer consume a grid cell.
- Touch question-navigation buttons are 44 px; phone text-entry controls remain at least 16 px. Registration headings and long usernames wrap, and password-column tracks can shrink.
- Font/CDN preconnections and low-priority preloads for already-required display metadata begin network work sooner. All script execution order, integrity attributes and inline application logic remain unchanged.
- Lesson/quiz search coalesces rapid typing over 150 ms, preserves input focus, supports composed text and Enter, and ignores callbacks for replaced views. Clearing or changing filters remains immediate.
- Legacy lesson-title lookup prepares its normalized candidate list once per grouping call instead of once per assessment. Live access, completion, readiness and attempt data are not cached.

## Validation

116 selected automated checks passed: lesson/quiz browsing, all-course navigation, client state and answer-save retries/races, flags, full SAT review, HTML script boundaries, math and English rendering, calculator, registration, device UI, mixed assignments, daily group scores, notifications and response security headers.

New search cases cover rapid input, final-result actions, preserved focus, navigation during a pending search, immediate clearing/filtering, composed text and unchanged live-availability filtering. Two older fixtures were corrected: the client-state harness now loads the existing ACT2 catalog dependency, and the script-order test checks executable script elements rather than preload links.

The three edited CSS files parse successfully. Student and instructor script order and inline bodies match the base revision exactly. Every preload URL matches an existing script request. Served web/ and portal-static/ copies match.

Synthetic benchmark: grouping 500 legacy SAT quiz titles over 20 measured runs after 5 warmups had median 251.2 ms before and 6.0 ms after, with identical grouped results. This is a local microbenchmark, not a measured improvement in user-perceived page loading or Core Web Vitals.

## Verification limits

The live public sign-in page loaded in the cloud browser. The managed preview daemon reported http://terminal.local:4173/ but the browser returned ERR_CONNECTION_REFUSED. The prescribed infrastructure diagnostics did not expose an application defect. No alternative browser/server path was used. Mobile/tablet rendering, physical devices, Safari/Firefox, and authenticated live student/instructor flows remain visually unverified. Automated DOM tests do not substitute for layout-engine checks.

No database, authentication policy, scoring, question bank, exam timing, answer-saving implementation, service worker, security header or deployment-domain changes are included. Existing open tabs are not force-reloaded.
