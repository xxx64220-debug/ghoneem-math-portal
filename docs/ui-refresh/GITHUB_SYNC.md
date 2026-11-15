# Deployed frontend source sync — 15 November 2026

Production Site version: 196. Source commit: `e5d08cc6bc7551bfc0ccfe47ed913489c4581746`.

This snapshot reconciles the deployed portal's top-level frontend sources and icons into `web/` and the existing GitHub `dist/` mirror. It includes the same-page Desmos popup, stable SVG flags, the History-safe study planner and their focused regression tests. Two additive SQL definitions from the earlier UI release are retained for the exam annotations and spaced notebook retries; this GitHub sync does not apply them to a database.

The pull request starts from GitHub main `aced31c40a6087febb395f9a6bf1587cc0226a2e`, retaining its monitoring workflows, notification performance upgrade, security work and bank releases. This is a frontend synchronization, not a claim that historical Sites and GitHub backend/content repositories are fully identical. Source/student audit exports, credentials and private answer material are excluded. Broader backend/source parity should be reviewed before using this branch as a replacement deployment source.

Validation on the exact deployed frontend: 640 CommonJS regression checks passed, three pre-existing skips; 77 focused runner/planner/calculator checks passed; 34 browser checks passed at 360/390/900/1280px. The production build checked 4,996 assets and 225 local links with no broken links. New CI runs the 77 focused regressions against GitHub's frontend mirror.

The deploy succeeded at 04:27 UTC. The pre-deployment read-only activity check found no active non-test timed attempts and no open published assignment windows. The browser rehearsal uses synthetic records and the real official Desmos frame; no student assessment was submitted. A signed-in production walkthrough was blocked by existing browser approval, and direct asset retrieval from this executor was blocked. See the screenshots and repair report alongside this file.
