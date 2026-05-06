# GH-533: Migrate Deterministic Encryption to Non-Deterministic + Blind Index

GitHub: #533

## Summary

Switch `encrypts` from `deterministic: true` to non-deterministic for email and telephone columns,
and use blind index columns for search. This enables encryption key rotation, which is impossible
with Rails deterministic encryption.

## Current State

### User models (principal DB) — blind index already exists

| Table             | Encrypted column          | Blind index             | Status      |
| ----------------- | ------------------------- | ----------------------- | ----------- |
| `user_emails`     | `address` (deterministic) | `address_bidx` (UNIQUE) | Implemented |
| `user_telephones` | `number` (deterministic)  | `number_bidx` (UNIQUE)  | Implemented |

### Staff models (operator DB) — blind index missing

| Table              | Encrypted column          | Blind index | Status              |
| ------------------ | ------------------------- | ----------- | ------------------- |
| `staff_emails`     | `address` (deterministic) | None        | **Needs migration** |
| `staff_telephones` | `number` (deterministic)  | None        | **Needs migration** |

## Proposed Changes

1. Add blind index columns to staff models (`address_bidx`, `number_bidx`).
2. Switch `encrypts :address` and `encrypts :number` from `deterministic: true` to default
   (non-deterministic) in `Email` and `Telephone` concerns.
3. Update all query paths to use blind index columns instead of encrypted column `WHERE` clauses.
4. Backfill blind index values for existing staff records.

## Existing Infrastructure

- `IdentifierBlindIndex` service: HMAC-SHA256 with `IDENTIFIER_BIDX_SECRET` credential.
- `UserEmail#set_address_digests` and `UserTelephone#set_number_digests` callbacks already exist.

## Implementation Status (2026-04-07)

**Status: PARTIALLY DONE**

Done:

- User emails: `address_bidx` column and index exist (migration `20260208170000`).
- User emails: `address_digest` column added (migration `20260210120000`).
- `IdentifierBlindIndex` service and callbacks functional for user models.

Remaining:

- `email.rb` concern: `encrypts :address, deterministic: true` still present (line 22).
- `staff_email.rb`: `encrypts :address, deterministic: true` still present (line 72).
- Staff emails: no `address_bidx` column in `operator_schema.rb`.
- Staff telephones: no `number_bidx` column.
- Query paths not yet migrated to blind index lookups.

## Improvement Points (2026-04-07 Review)

- Split schema work, backfill, and query migration into separate deploy steps. This is a multi-db
  change and should not remain a single undifferentiated migration note.
- Add a concrete audit of every lookup path that still queries encrypted columns directly so the
  plan can prove when the blind-index rollout is actually complete.
