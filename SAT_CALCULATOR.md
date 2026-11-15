# SAT Desmos calculator — 15 November 2026

SAT attempts open the official College Board calculator in a floating window on the same question page: https://www.desmos.com/testing/collegeboard/graphing

The desktop window supports dragging, keyboard movement, resizing and enlargement. On phones it opens below the question in a compact popup, with an Enlarge button. Close/reopen and question changes retain the same frame and expressions; a new attempt resets it. Reload is explicit and stays inside the popup. There is no separate-tab action.

The frame is created only on first use. It receives no user, question or attempt identifiers, suppresses its referrer, and cannot open popups or navigate the parent. Calculator use does not write answers, change deadlines or submit an attempt. Non-SAT attempts cannot open it. Escape works on the portal controls; keyboard events inside the third-party frame cannot propagate to the portal.

This is a practical website integration, not the Desmos API. A cross-origin frame limits resizing/configuration control and prevents reliable inspection of calculator readiness or expressions. Network errors offer an in-page reload. Desmos or browser policy changes could affect embedding.

For a supported integration with more control, use an appropriately licensed Desmos API key and the matching SAT configuration. Desmos currently offers personal, Starter and Enterprise plans with different permissions. Select the appropriate plan before enabling the API; do not reuse a demo/trial key for production. The legacy `sat-calculator-config.js` remains disabled and is not loaded by the page. No key was purchased or enabled in this release.

Official references checked 15 November 2026:

- https://www.desmos.com/partners
- https://www.desmos.com/my-api
- https://help.desmos.com/hc/en-us/articles/49078363315725-API-Plans-for-Commercial-Use
- https://www.desmos.com/api/v1.12/docs/index.html

See `docs/ui-refresh/DESMOS_POPUP.md` and `docs/ui-refresh/FLAG_PLANNER_FIX.md` for implementation verification and limitations.
