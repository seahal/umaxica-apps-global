# Turnstile Environment Toggle

## Status

Superseded (2026-05-11).

> **Superseded notice (2026-05-11):** The app-level Turnstile toggle is no longer planned. Test and
> development environments are expected to use environment-specific Turnstile credentials or
> equivalent operational configuration instead of a code-level enable/disable switch.

## Context

GitHub issue `#630` tracked the need to disable Cloudflare Turnstile without a code change when the
service is unavailable or should be bypassed in a controlled environment.

## Decision

The application does not need a code-level Turnstile enable/disable switch.

Operational configuration is expected to cover environment differences, including test and
development setups that can use credentials or local configuration appropriate to that environment.

## Consequences

- The historical toggle design is retained only as a record.
- Future work should rely on environment-specific configuration rather than an application flag.

## Related

- Former plan: `plans/archive/restoration-a9-turnstile-environment-toggle.md`
