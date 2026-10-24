# Portal security review — 19 October 2026, Cairo

Scope: current GitHub main `a91fa1b`, existing hosted Site version 95, and the
existing production Supabase project. The deployed Site is newer than GitHub;
the website patch preserves its newer exam, bank and diagnosis functionality.

## Corrections

| Finding | Result |
| --- | --- |
| KaTeX 0.16.9 has published URL, HTML and expansion advisories | Pin 0.18.2 in both pages and the math verification runtime; explicitly disable trusted rendering and limit expansion/size. |
| Supabase JS 2.45.0 includes affected auth-js | Pin 2.50.0, which uses patched auth-js 2.70.0; update the browser SDK and the exact current source of all 15 existing Edge Functions. |
| CDN scripts/styles lacked integrity verification | Add SHA-384 SRI for KaTeX JS, auto-render, CSS and Supabase JS; compare downloaded CDN bytes with the exact locked npm packages. |
| CSV formula neutralization missed leading whitespace/control characters | Neutralize these string values and headings; retain ordinary text, escaped quotes and numeric cells. |
| Missing document-level browser restrictions | Add no-referrer and a baseline meta CSP disabling base URLs, plugin objects and off-origin form submissions. This is not a complete script CSP or clickjacking defense. |

Advisories:

- <https://github.com/KaTeX/KaTeX/security/advisories/GHSA-238p-pmpm-9mq7>
- <https://github.com/KaTeX/KaTeX/security/advisories/GHSA-3wc5-fcw2-2329>
- <https://github.com/supabase/auth-js/security/advisories/GHSA-8r88-6cj9-9fh5>

Dependency findings identify affected packages; they do not establish exploitation
of the portal. In particular, the auth-js issue concerns malformed IDs passed to
admin methods. Existing server-generated IDs mitigate those paths, and the
dependency update removes the affected implementation.

## Verified controls

- All 48 portal tables in `public` and `portal_private` have RLS enabled.
- All nine readable public views use `security_invoker=true`.
- No public SECURITY DEFINER function is executable by `anon`.
- Every portal SECURITY DEFINER has a fixed search path; authorization definitions
  do not use editable `user_metadata` or `raw_user_meta_data`.
- Both storage buckets are private. No private key or service-role credential was
  found in the scanned current public text assets. `.env` and `.git/config`
  requests returned 404.
- The current Edge Functions verify identities with `auth.getUser()`, then load
  active role/status from the database and check the device/session RPC. The
  synthetic auth tests exercise forged role metadata, invalid JWTs, suspension,
  missing profiles, revoked sessions, and staff/admin separation.
- Production catalog checks are read-only. No schema, student records, grades,
  subscriptions, group memberships, notification preferences or question records
  were edited by this security release.

The advisor also reports 26 tables with RLS but no policies. They are deny-by-default
tables used by guarded RPCs or private archives; adding broad policies would weaken
them. Eighteen authenticated SECURITY DEFINER warnings include RLS helpers and
staff RPCs. Staff endpoints have explicit role/scope guards; RLS helpers must remain
callable by policies. Their presence is recorded, not treated as an automatic
instruction to revoke every function. This is not an exhaustive proof of every
possible authenticated RPC combination or metadata inference.

## Repeatable checks

`.github/workflows/security.yml` runs on PRs and pushes to main, plus manual
dispatch. It installs lockfiles with lifecycle scripts disabled, audits all five
dependency sets down to low severity, scans public artifacts, executes hostile
markup/math/CSV/auth/CORS regressions and runs isolated account/group authorization
suites. It never connects tests to production. Existing CI gates remain intact.

Local verification passed: 134 selected GitHub JavaScript tests, the focused
security/auth/figure/passage suite, and 155 isolated PostgreSQL account/group
gates. All five npm audits reported zero known vulnerabilities. Browser cases keep
network-isolated SDK fixtures; their local documents omit SRI for deliberately
substituted fixture bytes. Separate security tests validate the real production
SRI against locked package bytes. Managed browser tooling is unavailable locally;
actual browser execution is delegated to GitHub CI.

```sh
node scripts/security-public.cjs
node --test tests/security.test.cjs tests/auth_security.test.cjs tests/cors.test.cjs
node tests/portal_management_db.cjs
node tests/group_isolation_db.cjs
# Optional live HTTP checks: explicit, read-only, no real login or notification send.
python scripts/security-live.py --allow-live-read-only
```

`supabase/sql/security_audit.sql` is a reusable read-only catalog query. Its six
finding arrays were empty in production on this review. Re-run it alongside the
Supabase Security Advisor after database permission changes.

## Deployment and rollback evidence

`security-releases/20261019/edge-before.json` preserves the exact pre-update
function source/configuration; `edge-receipts.json` records the 15 version changes.
Every function was read back and compared byte-for-byte with its original source
after substituting only `supabase-js@2.45.0` with `supabase-js@2.50.0`. Existing JWT
gateway flags and all other source bytes were preserved. The canary returned 401
for both missing and invalid bearer tokens. No valid account was used for probes.
Only if a concrete regression occurs, restore that function's captured files,
entrypoint and JWT setting; record that rollback because it restores the old SDK.

## Remaining configuration work and limits

1. **Compromised-password protection is disabled.** Enable it in the existing
   project's Auth password settings if the plan supports it. Supabase documents
   availability on Pro and above. No billing or Auth setting was changed here.
   <https://supabase.com/dashboard/project/wfhurjyouemahvkcfkdz/auth/providers?provider=Email>
   <https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection>
2. **Hosting response headers need follow-up.** The inspected public HEAD response
   did not include CSP, X-Frame-Options, X-Content-Type-Options or HSTS. The baseline
   HTML policy cannot supply `frame-ancestors`, HSTS or nosniff. Configure these at
   the existing hosting edge, preserving login, calculator, fonts and embeds;
   verify the actual response headers afterwards. Do not claim the meta CSP fixes
   clickjacking or blocks every inline script.
3. Valid-login production journeys, MFA enrollment, password-reset mail and a full
   penetration test were not performed. Local role tests and unauthenticated live
   probes have narrower scope. Current-source credential scanning does not certify
   the entire Git history or third-party systems.
