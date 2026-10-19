# Portal security response headers

The existing Site's static adapter serves `_headers` as an ordinary file and
does not enforce its rules. A live attempt was verified, then reverted to the
previous working version. Merely adding that file is not a security fix here.

`hosting/portal-response.mjs` is the response handler used by the existing Site's
Worker build. It serves the portal's original HTML, JavaScript, styles, SVG and
JSON bytes and attaches these actual HTTP response headers:

| Header | Value |
| --- | --- |
| Strict-Transport-Security | `max-age=31536000` |
| X-Content-Type-Options | `nosniff` |
| X-Frame-Options | `DENY` |
| Referrer-Policy | `no-referrer` |
| Content-Security-Policy | `base-uri 'none'; object-src 'none'; form-action 'self'; frame-ancestors 'none'; upgrade-insecure-requests` |

The CSP blocks framing and plugin objects, but is not a restrictive script CSP.
HSTS is host-only: it neither includes subdomains nor requests preload. Existing
Supabase authentication, Desmos, SRI pins, timers and client-side data flow remain
in the original page bytes. No student-data or database write is part of this
change.

The complete build is retained in the existing Site source repository at commit
`1ff4242e96f91b666cf934e4db25fee20431bc2a`. It uses the supported Sites/Vinext
build with a small custom response entrypoint. `sites()` integration and the
original project ID are retained. `portal-static/` preserves the prior static
input; `scripts/prepare-portal-assets.mjs` overlays current `web/` edits and emits
54 text responses plus 1,519 binary assets. All binary build hashes were compared
against their source, and every bundled text response was compared byte-for-byte.
Binary responses pass through the platform ASSETS binding and receive the same
headers. No separate upstream proxy, secret, bucket, project or custom domain is
created.

Publishing changes must use the existing Site's source/build workflow. A raw
static deployment from an older GitHub checkout does not install this response
layer. The handler and its independent regression checks are mirrored here for
review and CI, without overwriting the newer production question-bank/runtime
work that is present in the Site source.

Validation:

- `node --test tests/response_headers.test.mjs` checks all available text routes,
  original bytes, MIME types, HEAD, root/admin aliases, ETags/304, protected error
  responses, method rejection and binary forwarding.
- `.github/workflows/security.yml` runs these regressions with the existing
  security checks; no CI test connects to production.
- `python scripts/check-security-headers.py --allow-live-read-only` checks actual
  headers on the root, administrator routes, service worker, calculator script,
  stylesheet, question diagram and missing private-file path.

Managed browser tooling is unavailable in this local environment. The response
tests exercise the bundled worker directly; existing browser journeys remain
covered by GitHub CI and unchanged frontend bytes.

## Password-protection eligibility

The production Supabase organization currently reports `plan=free`. Supabase's
built-in leaked-password protection requires Pro or above; Pro is advertised from
USD 25 per month, with usage/additional-project charges depending on the account.
No upgrade, billing change, password reset or authentication-setting change has
been performed. Enabling the native protection requires an explicitly approved
paid upgrade and access to the Auth configuration afterward.

- <https://supabase.com/docs/guides/auth/password-security>
- <https://supabase.com/pricing>
