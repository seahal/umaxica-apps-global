# GH-231: Configure CSP in Rails

GitHub: #231

## Summary

Review and harden the Content Security Policy configuration. The CSP initializer exists but may need
tightening for production readiness.

## Scope

- Audit the current CSP directives in `config/initializers/content_security_policy.rb`.
- Tighten directives to match actual asset sources and inline usage patterns.
- Ensure nonce-based script and style protection is correctly applied across all surfaces.
- Verify CSP headers are present in responses for all domains (app, org, com).

## Related

- GH-266: Set up Permissions-Policy.

## Implementation Status (2026-04-07)

**Status: COMPLETE**

`config/initializers/content_security_policy.rb` contains meaningful directives: default-src,
font-src, img-src, object-src(:none), script-src, frame-src, style-src, connect-src. Nonce-based
inline script/style protection enabled. This issue can be closed.

## Improvement Points (2026-04-07 Review)

- Tie the plan to the current initializer and response headers. This task needs a surface-by-surface
  verification table, not only a policy statement.
- Add explicit regression tests for nonce usage and header presence on `app`, `org`, and `com`
  before changing enforcement further.
