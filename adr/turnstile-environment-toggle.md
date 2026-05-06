# Turnstile Environment Toggle

## Status

Accepted on 2026-04-07.

## Context

GitHub issue `#630` tracked the need to disable Cloudflare Turnstile without a code change when the
service is unavailable or should be bypassed in a controlled environment.

## Decision

The application honors `CLOUDFLARE_TURNSTILE_ENABLED` through `Jit::Security::TurnstileConfig`.

When the toggle is disabled:

- Turnstile widgets are not rendered in visible or stealth forms.
- Server-side verification short-circuits successfully.
- Existing sign and contact flows continue without Turnstile dependency.

## Evidence

- `lib/jit/security/turnstile_config.rb` exposes `enabled?`.
- `lib/jit/security/turnstile_verifier.rb` returns a success response when the toggle is disabled.
- `app/views/shared/_cloudflare_turnstile.html.erb` and
  `app/views/shared/_cloudflare_turnstile_stealth.html.erb` do not render widget markup when the
  toggle is disabled.
- `app/views/core/app/application/_cloudflare_turnstile.html.erb` also suppresses widget rendering
  when disabled.
- `test/unit/jit/security/turnstile_verifier_test.rb` verifies the disabled short-circuit.
- `test/integration/turnstile_forms_test.rb` verifies that representative forms omit the widget when
  disabled.

## Consequences

- Operators can bypass Turnstile without changing application code.
- The disable path is explicit and test-covered, so future changes should preserve the same
  non-blocking behavior.

## Related

- Former plan: `plans/backlog/gh630-turnstile-environment-toggle.md`
