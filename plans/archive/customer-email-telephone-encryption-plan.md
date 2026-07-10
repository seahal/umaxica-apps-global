# Customer Email / Telephone Encryption Plan

## Status

Completed and archived (verified 2026-05-19).

This plan is historical. It was written before the `Customer` actor family was renamed to `Visitor`;
the implemented runtime uses `VisitorEmail` / `VisitorTelephone` models backed by the
`visitor_emails` / `visitor_telephones` tables in `db/com_principal_schema.rb`.

## Origin

Spun out from `plans/backlog/deterministic-encryption-migration-plan.md` and
`plans/backlog/gh533-encryption-blind-index-migration.md` on 2026-05-07.

The original com-side migration was folded into GH-533, but the auth tables had a schema-dump
uncertainty that made them a precondition rather than a side-effect. That uncertainty is now
resolved by `db/com_principal_schema.rb`, and the runtime actor family has since been renamed from
customer to visitor.

## Goal

Bring the com-side visitor email and telephone credentials to encryption parity with the app and org
sides so that key rotation is possible across **all** auth-relevant actor families.

This plan was a peer of `plans/archive/deterministic-encryption-migration-plan.md`. The shared
`Email` and `Telephone` concerns no longer use deterministic encryption.

## Final State (verified 2026-05-19)

### Models

- `app/models/visitor_email.rb`: `class VisitorEmail < ComPrincipalRecord`. Includes the shared
  `Email` concern. Lookup uniqueness is enforced through `address_digest`; the legacy `address_bidx`
  column has been retired.
- `app/models/visitor_telephone.rb`: `class VisitorTelephone < ComPrincipalRecord`. Includes the
  shared `Telephone` concern. Lookup uniqueness is enforced through `number_digest`; the legacy
  `number_bidx` column has been retired.

### Database state

The schema-dump precondition is resolved by the current `com_principal` database dump:

- `db/com_principal_schema.rb` defines `visitor_emails.address_digest` with a partial unique index.
- `db/com_principal_schema.rb` defines `visitor_telephones.number_digest` with a partial unique
  index.
- `db/com_principals_migrate/20260329020000_create_customer_identities.rb` is the historical create
  migration, and later migrations rename the runtime actor family to `visitor`.
- `db/com_principals_migrate/20260512111000_remove_customer_identifier_bidx_columns.rb` retires the
  legacy com-side blind-index columns after digest migration.

The shared `Email` / `Telephone` concerns no longer carry `deterministic: true` as of 2026-05-10.
Visitor now uses the same non-deterministic encrypted identifier path as client and operator.

## Completed Migration Strategy

### Phase 0: Resolve the schema-dump precondition

This gate is closed.

Output: `db/com_principal_schema.rb` exists and owns the visitor email / telephone tables.

### Phase 1: Confirm parity with user-side blind-index shape

Phase 0 established ground truth. The final shape is:

- `visitor_emails.address_digest` with `WHERE address_digest IS NOT NULL` partial-unique index.
- `visitor_telephones.number_digest` with `WHERE number_digest IS NOT NULL` partial-unique index.
- Legacy `*_bidx` columns are removed after the digest path is in place.

The legacy `address_bidx` / `number_bidx` indexes are intentionally gone.

### Phase 2: Backfill blind-index values

Backfill support exists through `IdentifierBlindIndexBackfill`, and the final runtime lookup path is
digest-based.

### Phase 3: Audit visitor-side query paths

The visitor-side query paths were migrated to digest-based lookups. The relevant surface remains:

- `app/controllers/sign/com/...` (sign-in, OTP, configuration flows for the `:com` IdP host).
- `app/controllers/concerns/sign/com_verification_base.rb` (already known to read visitor email
  state).
- `app/services/...` for visitor reconciliation services.
- Tests, fixtures, and any rake tasks that touch the visitor side.

### Phase 4: Concern flip

The shared `Email` and `Telephone` concerns have already dropped `deterministic: true`, and the
app/org/com actor credential models use the shared non-deterministic encrypted identifier path.

### Phase 5: Visitor-included key-rotation drill

The rotation drill includes visitor rows through
`test/integration/identifier_encryption_rotation_drill_test.rb`.

### Phase 6: Cleanup

1. Remove any dual-write scaffolding specific to visitor.
2. Drop legacy visitor-side columns retained "just in case" only after a deploy cycle confirms the
   new path is solid.
3. Keep this archived note as the record that the original `guest_schema` uncertainty resolved to
   the `com_principal` database.

## Risks

- **Phase 0 may surface a bigger problem.** Resolved: the implemented tables are schema-managed
  under `com_principal`.
- **Concern-flip coupling.** Resolved: the shared concern flip has landed for all actor families.
- **`set_address_digests` already wired.** Visitor models already have the digest callbacks in
  place. Make sure the backfill (Phase 2) does not double-run them or skip rows where the callback
  failed historically.

## Acceptance Criteria

- [x] Phase 0 resolved: `db/com_principal_schema.rb` exists and matches the `visitor_emails` and
      `visitor_telephones` model annotations.
- [x] Digest columns and partial-unique indexes confirmed on `visitor_emails` and
      `visitor_telephones`.
- [x] Backfill complete; every existing visitor email / telephone row has a populated `*_digest`.
- [x] Visitor-side query paths audited and migrated to digest lookups.
- [x] `deterministic: true` removed from the concerns and per-model overrides for all actor
      families.
- [x] Re-encryption path covered for visitor rows by `IdentifierEncryptionReencrypt`.
- [x] Key-rotation drill rerun with visitor rows present in
      `test/integration/identifier_encryption_rotation_drill_test.rb`.

## Related

- `plans/archive/deterministic-encryption-migration-plan.md` — peer historical plan for client /
  operator.
- `plans/archive/gh533-encryption-blind-index-rotation.md` — GitHub #533 historical status.
