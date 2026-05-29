# Security Headers

## Current Standard

Browser security headers must be configured to keep the public application surfaces eligible for an
A+ grade on both:

- Mozilla / MDN HTTP Observatory: `https://developer.mozilla.org/en-US/observatory`
- SecurityHeaders.com: `https://securityheaders.com/`

This target applies to the production public hosts, including `www.umaxica.app`, and to future
changes that affect CSP, Permissions-Policy, cookie transport, SRI-sensitive external scripts, CORP,
COEP, COOP, HSTS, Referrer-Policy, X-Content-Type-Options, frame protections, or related browser
security headers.

## Implementation Notes

- CSP is configured in `config/initializers/content_security_policy.rb`.
- `form-action` stays same-origin except for the Google and Apple OAuth endpoints used by app social
  sign-in/sign-up. Browsers enforce `form-action` across those OAuth navigations.
- Permissions-Policy, Cross-Origin-Embedder-Policy, Cross-Origin-Opener-Policy, and
  Cross-Origin-Resource-Policy are configured in `config/initializers/permissions_policy.rb`.
- Session cookie transport is configured through `config/initializers/session_store.rb` and
  `lib/session_cookie_config.rb`.
- Turnstile scripts should only be loaded on pages that render a Turnstile form, and inline
  Turnstile setup scripts must use CSP nonces.
- Do not re-enable Rails' legacy `Feature-Policy` header; use the explicit `Permissions-Policy`
  header instead.
- `Expect-CT`, `Report-To`, `NEL`, `Server`, and CDN-managed compatibility headers may be added or
  rewritten by the edge provider. If scanners flag those, verify whether the fix belongs in Rails or
  the CDN configuration before changing application code.

When changing these areas, update focused regression tests and re-scan the affected public host
after deployment.
