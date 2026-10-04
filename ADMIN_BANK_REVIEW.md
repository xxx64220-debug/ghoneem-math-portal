# Paged question bank and review queue

The former bank loaded every full question and attachment before filtering, and displayed only the first 300 matches. Staff now receive 50 metadata rows per server-filtered page. Every match is reachable, selections survive pagination and filters, and full questions, original source images, graphs and tables load when staff open Preview, Edit or View source.

The catalogue preserves stable UUIDs, original source codes, canonical lessons, detailed skills and recorded difficulty. Search covers the full original stem, IDs, source references, lesson, skill and hold reason even though list previews are truncated. The editor exposes detailed skill and source code separately while preserving the complete assets JSON. Difficulty labels remain recorded judgments; there is no invented ranking from student data.

Priority is deterministic: (1) structurally blocked content, (2) missing lesson/skill classification, (3) independent mathematics review pending, (4) explicitly independently solved. More published-exam uses sort first within each priority, with stable lesson/code/ID tie-breaks. Held historical exams are included in usage because students can still review them. Release checks and independently solved evidence are distinct. A release marker alone does not certify the answer or original figure.

The PDF source archive uses live bank eligibility rather than assuming that a linked question is usable. Missing, removed or held linked records cannot be selected. Source images and their decoding information are absent from list responses.

`supabase/sql/admin_bank_page.sql` installs one read-only RPC, denies anonymous callers, checks the live active staff profile and enforces instructor track assignments. It returns no answer keys or full assets. Page size is capped at 100; the UI requests 50. Search uses literal substring matching, including `%` and `_`, and never builds dynamic SQL. No student history, grades, question content or exam memberships change.

Apply the SQL once to the existing project after disposable database and browser checks pass. It refuses to overwrite an existing function. Deploy the matching web/dist files afterwards. Rollback the frontend to the preceding Site version before dropping this function with its exact signature; no data restoration is needed.

Validation: 129-row disposable database fixture covers three pages, stable order, literal search, missing keys, held sources, review evidence, payload size, absence of assets/keys and staff authorization. Browser fixtures cover 351 questions on desktop/mobile, the final page, retained selection, lazy original loading, retries and stale requests. Existing assessment, revision, graph-renderer and autosave regressions remain required. These checks do not mathematically certify the remaining source bank; original ambiguities remain held until sufficient evidence is available.
