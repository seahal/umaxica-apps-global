# Deterministic Encryption Migration Plan

## Issue

GitHub #533

## Status

Implemented through GH-533 (2026-05-10). Scope narrowed to **user + staff** only.

- The `{app,com,org}_contact_*` mirrors are out of scope and have been dropped from this plan.
- The `customer_email` / `customer_telephone` side has been split into its own plan
  (`plans/backlog/customer-email-telephone-encryption-plan.md`) because the customer table's
  schema-dump status is uncertain and resolving that is a prerequisite, not a side effect.

The previous draft also framed `staff` as the only side needing migration — that was wrong even
within the user+staff scope, because `user_email` / `user_telephone` still carry
`deterministic: true` despite already having blind-index columns. Both user and staff need the flag
flipped before any key rotation is possible.

## Goal

Enable encryption key rotation for email and telephone columns on the **user (principal DB) and
staff (operator DB)** sides. Rails' deterministic encryption mode cannot be re-keyed;
non-deterministic encryption with HMAC blind-index lookups can.

The migration is not just a renaming of how rows are queried — it removes the cryptographic
constraint that has prevented rotating `ActiveRecord::Encryption.primary_key`, `deterministic_key`,
and `key_derivation_salt` since the columns were introduced.

## Current State (verified 2026-05-07)

### Blind index columns

| Model             | DB        | `*_bidx` | `*_digest` | Migration                          |
| ----------------- | --------- | -------- | ---------- | ---------------------------------- |
| `user_email`      | principal | ✅       | ✅         | `20260208170000`, `20260210120000` |
| `user_telephone`  | principal | ✅       | ✅         | existing                           |
| `staff_email`     | operator  | ✅       | ✅         | `20260509120000`                   |
| `staff_telephone` | operator  | ✅       | ✅         | `20260509120000`                   |

### `deterministic: true` declarations in scope

No remaining `deterministic: true` declarations exist on user / staff / customer auth email or
telephone identifier models. Lookup paths now use HMAC blind-index columns through `find_by_address`
/ `find_by_number` or direct `*_digest` queries.

### Existing infrastructure

- `IdentifierBlindIndex` service (HMAC-SHA256, `IDENTIFIER_BIDX_SECRET` credential) — already used
  by user-side callbacks.
- `UserEmail#set_address_digests`, `UserTelephone#set_number_digests` — populate `*_bidx` /
  `*_digest` on save. Equivalent callbacks need to be added for staff (or hoisted into the shared
  concerns).

## Migration Strategy

### Phase 1: Staff schema parity

Add `address_bidx`, `address_digest`, `number_bidx`, `number_digest` columns and partial-unique
indexes (`WHERE *_bidx IS NOT NULL`) to `staff_emails` and `staff_telephones`, in
`db/operators_migrate/`. Mirror the shape that already exists on `user_emails` / `user_telephones`.

Backfill: write a one-time data migration (or runner script) that recomputes `IdentifierBlindIndex`
for every existing row. Do **not** rely on a `save` callback alone, because `save` will rewrite the
encrypted column in non-deterministic mode and break lookups until Phase 3 lands.

### Phase 2: Query path audit and migration

Audit every place that queries `user_email`, `user_telephone`, `staff_email`, or `staff_telephone`
by encrypted value. Replace each lookup with a `*_bidx` / `*_digest` query. Cover at minimum:

- Sign-in / OTP flows (`app/services/...`, `app/controllers/sign/...`).
- Account reconciliation services (find-by-email, find-by-phone).
- Admin / staff console search.
- Rake tasks and one-off scripts under `lib/tasks/`.
- Tests that assert `where(address: ...)` / `where(number: ...)` against encrypted columns (these
  will start failing once Phase 3 lands).

Output of this audit should be a checked-in list (or PR description) of every call site that was
updated, so the rollout can prove completion.

### Phase 3: Remove `deterministic: true` (coordinate with customer plan)

Once every lookup uses the blind-index columns:

1. Remove `deterministic: true` from the four sites listed above.
2. Hoist the `set_*_digests` callbacks into the shared concerns where appropriate.
3. **Coordinate with the customer plan.** Because the `Email` and `Telephone` concerns are shared,
   flipping the concern flag in this plan automatically flips it for the customer models too. Do not
   ship Phase 3 until the customer plan's blind-index parity work has also landed; otherwise
   customer lookups will silently break.
4. Run `bin/rails db:encryption:reencrypt` (or an equivalent migration job) so existing ciphertext
   is re-encoded under the non-deterministic scheme. Plan downtime or a zero-downtime approach
   (dual-read) up front; do not skip this step.

### Phase 4: Key rotation drill

Now that rotation is possible, prove it once end-to-end before declaring the work complete:

1. Add a new key to `ActiveRecord::Encryption.primary_key` chain, leave the old key as `previous`.
2. Re-encrypt with the new key.
3. Sign in / OTP all still work for both user and staff actors.
4. Drop the old key from the chain.

This drill becomes the regression contract: any future encryption-touching change must run this
drill in CI or staging.

### Phase 5: Cleanup

1. Remove dual-write / backward-compat scaffolding from the `set_*_digests` callbacks.
2. Drop legacy columns that were retained "just in case" (only after a deploy cycle confirms the new
   path is solid).
3. Document the rotation procedure in `docs/` so the next operator can do it without rediscovery.

## Risks

- Re-encryption of existing rows requires either downtime or a careful dual-read window. Do not
  hand-wave this away.
- Test fixtures and integration tests that build emails / phones on the fly will need to honor the
  same blind-index callbacks; otherwise tests will pass but production lookups fail.
- Phase 3 affects the shared concerns and therefore touches customer-side behavior. Sequence with
  the customer plan or you will ship a half-done migration.

## Acceptance Criteria

- [x] Blind-index columns and partial-unique indexes present on `staff_emails` and
      `staff_telephones`.
- [x] All four `deterministic: true` declarations in scope removed.
- [x] Every user / staff lookup site audited and migrated to blind-index queries (audit list checked
      in).
- [x] `bin/rails db:encryption:reencrypt` path is implemented by `IdentifierEncryptionReencrypt`.
- [x] Phase 4 key-rotation drill executed successfully in automated integration coverage.
- [x] Documentation update describes the rotation procedure for operators.

## Related

- `plans/backlog/gh533-encryption-blind-index-migration.md` — GitHub issue #533 status, kept in sync
  with this plan.
- `plans/backlog/customer-email-telephone-encryption-plan.md` — customer-side counterpart. Phase 3
  of this plan must be sequenced with the customer plan because they share the `Email` and
  `Telephone` concerns.
