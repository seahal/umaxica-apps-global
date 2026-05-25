# Actor Current Context API Cleanup

## Status

Active.

Controller lifecycle work that depends on this Actor API is now tracked in
`plans/active/controller-boundary-lifecycle-unification.md`. This plan remains active only for
lower-level Actor API cleanup, including migration-only direct readers.

## Decision

Implement the `Actor` current-context API described by `adr/actor-current-facade.md` and
`docs/architecture/current_context.md`.

This active plan supersedes older CurrentAttribute and compatibility-reader cleanup notes in
`plans/backlog/` where they conflict with the accepted Actor direction.

## Scope

- Keep `Actor` as the only application-facing current-context API.
- Use `Actor.tld` as the only surface label API.
- Remove `Actor.surface` and `Actor.domain`; do not keep compatibility aliases.
- Move authentication-facing state toward `Actor.authn`.
- Remove `Actor.session` and `Actor.token`; use `Actor.authn.login_public_id` and typed
  authentication readers instead.
- Keep Action Policy's authorization context name as `:user`.
- Keep Actor reads shallow by default (`Actor.xxx.yyy`), with only
  `Actor.configuration.<namespace>.<value>` allowed as a four-layer exception for typed
  configuration namespaces such as `sign`.

## Superseded Backlog Notes

- `plans/archive/actor-support-integration-test-coverage.md` remains useful for lifecycle coverage
  shape, but tests should target `Actor.tld`, `Actor.authn`, and `Actor.preferences`.
- `plans/archive/public-controller-preference-leak-test.md` remains useful for open-controller leak
  coverage, but tests should not use removed `Actor.surface` or `Actor.domain`.
- `plans/archive/action-policy-actor-context-rename.md` is not planned; keep the Action Policy
  context key as `:user`.
- `plans/backlog/gh610-decouple-session-id-from-token.md` remains relevant, but its runtime API
  target is `Actor.authn.login_public_id`.

## Implementation Notes

- Prefer replacing old plan assertions instead of adding compatibility shims.
- Do not flatten configuration namespace values into awkward third-layer names such as
  `Actor.configuration.sign_value`; use `Actor.configuration.sign.value` when the namespace carries
  meaning.
- If a previous plan expects `Current.*`, `Jumper`, `Apexer`, `Signer`, `Actor.surface`, or
  `Actor.domain`, treat that part of the plan as obsolete.
- Preserve only ideas that still fit the accepted Actor API, such as lifecycle reset coverage,
  preference fallback coverage, and explicit open-controller leak checks.
