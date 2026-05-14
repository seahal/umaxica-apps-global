# GH-558: Implement Refresh Token Rotation with Concurrency Control

GitHub: #558

## Status

**Closed 2026-05-10.** The existing one-time consume implementation is the accepted baseline.
`docs/security/refresh-token-rotation.md` now documents the current contract and records that Redis
JTI deduplication / short grace windows are intentionally deferred until a measured retry problem
requires them.

## Problem

Naive refresh token implementations suffer from race conditions:

- Concurrent refresh requests (multiple tabs, retries).
- Network failures causing lost responses.
- Token rotation invalidating legitimate clients.
- Replica lag or cache inconsistency leading to false negatives.

## Goals

- Ensure refresh operations are idempotent within a short window.
- Prevent double rotation under concurrent requests.
- Allow safe retry behavior without weakening security.
- Maintain clear detection of replay attacks.

## Design Overview

- Refresh token as stateful entity with rotation lineage stored in DB.
- Grace period for concurrent requests using the same token family.
- Replay detection: reuse of a consumed token triggers family-wide revocation.
- Redis-backed nonce/JTI deduplication for the grace window.

## Non-Goals

- Long-lived access token overlap.
- Weakened token revocation guarantees.
- Client-side coordination dependency.

## Implementation Status (2026-04-07)

**Status: PARTIALLY DONE**

Done:

- Refresh token rotation logic in `sign/refresh_token_service.rb` with one-time consume semantics.
- Family-based revocation: `refresh_token_family_id` tracked; all tokens in family revoked on reuse
  via `handle_refresh_token_reuse()`.
- Replay detection via `rotated_at` field and concurrent request detection.

Remaining:

- No grace period for concurrent requests.
- No Redis-backed JTI deduplication layer.

## Improvement Points (2026-04-07 Review)

- Reconcile this note with the existing `Sign::RefreshTokenService` implementation. Parts of the
  rotation contract already exist, so the remaining gap should be called out precisely.
- Separate already-landed replay handling from still-open grace-window or deduplication work so the
  issue does not duplicate `GH-612`.

## 2026-05-07 現状差分と改善として残すこと

Refresh token rotation の中核は現行ツリーで実装済み。

確認済み:

- `app/services/sign/refresh_token_service.rb` が存在する。
- `test/services/sign/refresh_token_service_test.rb` が存在する。
- session limit / token status management 側にも refresh token service を使うテストがある。

この文書は「rotation を実装する」計画ではなく、追加改善の判断メモとして残す。

残す改善:

- 現行 `Sign::RefreshTokenService` の仕様を docs 化する。
- short grace window が本当に必要か、既存の one-time consume / replay
  handling で足りるかを判断する。
- Redis / JTI deduplication は必須要件ではなく、必要性が確認できた場合だけ追加する。
- 追加する場合は、family-wide revocation を弱めないことをテストで固定する。
