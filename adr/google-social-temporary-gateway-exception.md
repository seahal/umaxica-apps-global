# Google Social Temporary Gateway Exception

**Status:** Withdrawn (2026-06-02)

## Context

This ADR note previously allowed temporary Google social gateway work for `org` and `com` during QA
and implementation validation. That exception is no longer accepted.

## Decision

The temporary exception is withdrawn:

- `org` does not offer Google social sign-up or sign-in.
- `org` does not offer social account linking or unlinking for production.
- `com` remains no-social and does not offer Google social sign-up or sign-in.
- `app` Google and Apple social login are unchanged and remain out of scope for this cleanup.
- Apple remains app-only; no Apple social provider is added to `org` or `com`.

Org production sign-in is limited to a personal identifier plus local verifiers: passkey, passcode,
and any existing org TOTP path if present. External social providers are not org sign-in methods.

## Consequences

- The old org/com Google social flags are not valid configuration.
- The old org/com Google provider IDs are not valid production providers.
- Temporary gateway tags and cleanup exceptions must not remain in runtime code, tests, active
  plans, ADRs, or stable docs.
- Reintroducing social login to `org` or `com` requires a new accepted ADR.
