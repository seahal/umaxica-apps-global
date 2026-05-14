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

**Status: CLOSED 2026-05-10**

Needs fresh audit to determine which placeholder services still exist. `TokenService` exists;
`CoreService` may have been removed. Boot-safety and `$stderr` override status unknown.

2026-05-10 audit and changes:

- `MessageService`, `NotificationService`, `AccountService`, `CoreService`, and `EventPublisher` are
  not present in `app/services` or `app/lib`.
- `Auth::TokenService` is implemented and covered by `test/services/auth/token_service_test.rb`; it
  is not a placeholder.
- Removed empty placeholder file `test/services/event_publisher_test.rb`.
- Active Record encryption configuration now resolves primary, previous, deterministic, and salt
  keys through `Jit::Security::ActiveRecordEncryptionKeyProvider`.
- Missing encryption credentials still fail in production, but development/test get deterministic
  fallback keys so boot safety is preserved for local/test environments.
- No global `$stderr` override was found in app/config/test code.

## Improvement Points (2026-04-07 Review)

- Re-audit the current code first. `TokenService` exists, `CoreService` may not, and the note needs
  a present-tense inventory before it can drive implementation.
- Split boot-safety work from service cleanup. Encryption-credential handling and placeholder
  service removal do not need the same review path.

## 2026-05-07 現状差分と改善として残すこと

この文書の placeholder 前提は一部古い。

確認済み:

- `app/services/auth/token_service.rb` は存在し、テストもある。
- `test/services/event_publisher_test.rb` が存在するため、`EventPublisher`
  は少なくとも現行テスト対象。

この文書は「TokenService placeholder cleanup」ではなく、未使用 service / event publisher / boot
safety の改善メモとして残す。

残す改善:

- 対象 placeholder service は現存しないため、この issue は閉じる。
- 今後 EventPublisher を再導入する場合は、新規 plan で実 event path、payload
  shape、失敗時の扱いを先に決める。
