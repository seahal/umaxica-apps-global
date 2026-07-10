# GH-558: Implement Refresh Token Rotation with Concurrency Control

GitHub: #558

## Status

**Deprecated 2026-05-19.** Do not use this plan as implementation direction. Its Redis/JTI
deduplication direction is rejected; token rotation concurrency must be handled with DB-backed state
and PostgreSQL row-level atomicity only. See `plans/active/token-rotation-concurrency-hardening.md`.

**Closed 2026-05-10.** The existing one-time consume implementation was the accepted baseline at
that time. `docs/security/refresh-token-rotation.md` now documents the current contract and records
that Redis JTI deduplication / short grace windows are intentionally deferred until a measured retry
problem requires them.

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

## 2026-05-07 What to leave as current differences and improvements

The core of Refresh token rotation is already implemented in the current tree.

Confirmed:

- `app/services/sign/refresh_token_service.rb` exists.
- `test/services/sign/refresh_token_service_test.rb` exists.
- There is also a test that uses refresh token service on the session limit / token status
  management side.

This document is not a plan to ``implement rotation,'' but is left as a memo for making decisions
about additional improvements.

Improvements to leave:

- Convert the current `Sign::RefreshTokenService` specifications into docs.
- Do you really need a short grace window or do you have an existing one-time consume / replay?
  Determine whether handling is sufficient.
- Redis / JTI deduplication is not a mandatory requirement and should be added only if the necessity
  is confirmed.
- If added, test to ensure that family-wide revocation is not weakened.
