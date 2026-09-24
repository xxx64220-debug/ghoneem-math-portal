# Read this before you run anything else

**Abdelrahman Ghoneem | 01116004434**

## 1. Replace 006 — the old one had the wrong field names

I originally guessed your bank's field names. They were wrong. Corrected against
your real setup.sql:

| Your bank | I had guessed | Consequence of the old version |
|---|---|---|
| `ans` (letter, 223 mc) | `a` | — |
| `opts` | `ch` | — |
| `accepted` (129 grid-in) | not read | **all 129 grid-ins skipped** |
| `rat` (rationale, 352) | `ex` | **every explanation lost** |
| `type` = `mc` / `spr` / `txt` | `mcq` / `grid_in` | type misread |
| `fig` = drawing spec | raw SVG | diagrams would not draw |

**Run the new `006_import_legacy_sat.sql` (replacing the old one) before you
import.** Verified on your actual 352 questions:

    imported 352, skipped 0
    223 multiple choice, 129 grid-in
    10 diagrams, 22 data tables, 0 missing explanations

Every stem, key and explanation was compared back to the source: zero mismatches.

## 2. NEVER run the whole setup.sql in the new project

Only the single `insert into public.site_content ...` line. The rest of that file
would attach the OLD portal's policies to your NEW tables — including:

    create policy "insert own attempts" on public.attempts
      for insert to authenticated with check (auth.uid() = user_id);

That grants students INSERT on `attempts`, which destroys the single-submission
guarantee: they could create unlimited attempts. If you have already pasted the
whole file, run this to check and clean up:

    select tablename, policyname from pg_policies
     where schemaname = 'public'
       and policyname in ('insert own attempts','read own attempts',
                          'manage own device sessions','students read content');

    -- if any rows come back:
    drop policy if exists "insert own attempts"        on public.attempts;
    drop policy if exists "read own attempts"          on public.attempts;
    drop policy if exists "manage own device sessions" on public.device_sessions;
    drop policy if exists "students read content"      on public.site_content;

Then re-run `003_policies.sql` and `005_function_hardening.sql`, and confirm with
`tests/adversarial_test.sql` (21/21 refused).

## 3. The figure renderer is in the client now

Your 10 geometry diagrams are drawing specs, not images — the old portal drew
them in JavaScript. `web/index.html` now contains an equivalent renderer for
lines, labelled angle arcs, and the embedded `extra` SVG charts.

Note on scale: bank items 0 and 5 have identical coordinates but read 61 deg and
74 deg, so these are schematic templates and the label is authoritative — the
same convention as the printed SAT, where figures are not drawn to scale.
