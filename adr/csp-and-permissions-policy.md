# CSP And Permissions-Policy

## Status

Accepted on 2026-04-10.

## Context

GitHub issues `#231` and `#266` tracked browser response header hardening for the application. The
goal was to keep browser feature access and inline asset execution constrained across all surfaces.

## Decision

The application uses both:

- Content Security Policy with nonce-based script and style protection
- Permissions-Policy with unused browser features denied and WebAuthn allowed

The implemented configuration is:

- CSP in `config/initializers/content_security_policy.rb`
- Permissions-Policy in `config/initializers/permissions_policy.rb`

## Evidence

- `config/initializers/content_security_policy.rb` defines policy directives and nonce support.
- `config/initializers/permissions_policy.rb` denies unused features such as camera, geolocation,
  microphone, and USB.
- `config/initializers/permissions_policy.rb` allows WebAuthn-related directives for
  `publickey-credentials-get` and `publickey-credentials-create`.
- Turnstile views use CSP nonce support for inline scripts.

## Consequences

- The response header policy is explicit and reviewable in code.
- Future changes to browser feature access should update the initializers and add regression tests.

## Related

- Former plan: `plans/backlog/gh231-configure-csp.md`
- Former plan: `plans/backlog/gh266-permissions-policy.md`
