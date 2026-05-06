# GH-617: Clean Up Placeholder Services and EventPublisher Runtime Safety

GitHub: #617

## Summary

Resolve service/runtime cleanup items around placeholder service objects, `CoreService`,
`EventPublisher`, and boot-time runtime safety.

## Scope

- Review empty or placeholder service objects:
  - `TokenService`
  - `MessageService`
  - `NotificationService`
  - `AccountService`
- Either implement the required domain behavior or remove placeholders.
- Repurpose or remove `CoreService` if it remains a stub.
- Decide whether `EventPublisher` is still part of the intended architecture.
- If `EventPublisher` stays, wire it to the real event/notification path and add meaningful tests.
- Guard Active Record encryption configuration against missing credentials so boot does not fail.
- Replace the global `$stderr` override with a library-specific workaround.

## Acceptance Criteria

- Placeholder services are either implemented intentionally or removed.
- `CoreService` no longer remains as an unused stub.
- `EventPublisher` is either integrated with the real architecture or removed cleanly.
- Boot behavior remains safe when encryption credentials are missing.
- The global `$stderr` override is no longer needed.

## Tests

- `EventPublisher` payload shape.
- Headers and metadata.
- Delivery failure handling.
- Runtime behavior when encryption credentials are missing.

## Source

- `docs/implementation/service-and-runtime-improvements.md`

## Implementation Status (2026-04-07)

**Status: NOT VERIFIED**

Needs fresh audit to determine which placeholder services still exist. `TokenService` exists;
`CoreService` may have been removed. Boot-safety and `$stderr` override status unknown.

## Improvement Points (2026-04-07 Review)

- Re-audit the current code first. `TokenService` exists, `CoreService` may not, and the note needs
  a present-tense inventory before it can drive implementation.
- Split boot-safety work from service cleanup. Encryption-credential handling and placeholder
  service removal do not need the same review path.
