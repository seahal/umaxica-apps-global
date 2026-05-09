# Customer Email / Telephone Encryption Plan

## Origin

Spun out from `plans/backlog/deterministic-encryption-migration-plan.md` and
`plans/backlog/gh533-encryption-blind-index-migration.md` on 2026-05-07.

The customer-side migration was originally folded into GH-533, but the customer auth tables have a
schema-dump uncertainty that makes them a precondition rather than a side-effect: until the
schema-dump status is resolved, no migration can be authored against `customer_emails` or
`customer_telephones` with confidence. This plan handles that resolution and the customer-side
migration in one place.

## Goal

Bring `customer_email` and `customer_telephone` to encryption parity with the user side (blind-index
columns + non-deterministic `encrypts`) so that key rotation is possible across **all**
auth-relevant actor families (user / staff / customer) at the same time.

This plan is a peer of `plans/backlog/deterministic-encryption-migration-plan.md`. The two plans
must be sequenced together at the "remove `deterministic: true`" step because they share the `Email`
and `Telephone` concerns — flipping the flag in one repo location simultaneously flips it for both.

## Current State (verified 2026-05-07)

### Models

- `app/models/customer_email.rb`: `class CustomerEmail < GuestRecord`. Includes the shared `Email`
  concern. `before_validation :set_address_digests` is wired. Validations on `address_bidx` and
  `address_digest` exist.
- `app/models/customer_telephone.rb`: `class CustomerTelephone < GuestRecord`. Includes the shared
  `Telephone` concern. Validations on `number_bidx` and `number_digest` exist. Same digest callback
  shape as `customer_email`.

### Database situation (the precondition)

The model annotations claim:

- `Table name: customer_emails`, columns include `address`, `address_bidx`, `address_digest`, with
  partial-unique indexes on `address_bidx` and `address_digest`.
- `Table name: customer_telephones`, columns include `number`, `number_bidx`, `number_digest`, with
  the same index shape.
- `Database name: guest`.

But `db/guest_schema.rb` **does not exist** in the committed tree. The only schema dumps under `db/`
are: `principal_schema.rb`, `operator_schema.rb`, `setting_schema.rb`, `chronicle_schema.rb`,
`notification_schema.rb`, `cache_schema.rb`, `queue_schema.rb`, `storage_schema.rb`,
`occurrence_schema.rb`, `avatar_schema.rb`, `redirector_schema.rb`, `search_schema.rb`,
`mark_schema.rb`, `symbol_schema.rb`, `token_schema.rb`. The `db/guests_migrate/` directory has
migrations for contact tables and a single
`20260329084527_add_email_preference_columns_to_customer_emails.rb` that _adds_ columns to
`customer_emails`, but nothing in the committed tree creates the table.

This means one of the following is true; resolve which one before proceeding:

1. The `customer_emails` / `customer_telephones` tables really do exist in the running database
   (created by an unmerged migration, an out-of-band SQL run, or a missing initial schema). The
   schema dump just hasn't been refreshed.
2. The model annotations are stale — copied from a sibling repo or a prior layout — and the tables
   don't actually exist on `guest`.
3. The customer auth tables are intentionally not yet schema-managed in this repo; they live in
   another DB or under a different naming scheme that the model file is no longer accurate about.

The shared `Email` / `Telephone` concerns still carry `deterministic: true`
(`app/models/concerns/email.rb:22`, `app/models/concerns/telephone.rb:20`). Customer therefore
inherits the same key-rotation lock-in as user and staff.

## Migration Strategy

### Phase 0: Resolve the schema-dump precondition

This is the gate. Do not proceed past this phase until the answer is in.

1. Run `bin/rails db:prepare` (or its multi-DB equivalent) against a fresh local DB and check
   whether `customer_emails` and `customer_telephones` get created. If they do, find which migration
   creates them and ensure that migration is committed and that `db/guest_schema.rb` is regenerated
   and committed.
2. If no migration creates them locally, search git history (and the regional repo) for
   `create_table "customer_emails"` to identify whether the table definition was lost in a prior
   rollback / repo split. If it was, write a fresh `create_table` migration in `db/guests_migrate/`
   matching the model annotation exactly (column types, defaults, indexes).
3. If neither path produces a definitive answer, escalate: the customer auth surface is broken at
   the persistence layer and that is a higher-priority problem than this encryption migration. Pause
   this plan, file a separate issue, and resume once persistence is sound.

Output: `db/guest_schema.rb` exists and is up to date, or the equivalent dump for whichever DB ends
up owning these tables.

### Phase 1: Confirm parity with user-side blind-index shape

Once Phase 0 establishes ground truth, verify that:

- `customer_emails.address_bidx` (with `WHERE address_bidx IS NOT NULL` partial-unique index).
- `customer_emails.address_digest` (with `WHERE address_digest IS NOT NULL` partial-unique index).
- `customer_telephones.number_bidx`, `customer_telephones.number_digest` (same shape).

If any of these are missing, add migrations under `db/guests_migrate/` (or whichever DB ends up
owning the tables) to add them, mirroring the user-side definitions in `db/principals_migrate/`.

### Phase 2: Backfill blind-index values

Recompute `IdentifierBlindIndex` for every existing `customer_email` and `customer_telephone` row.
Use the same approach as the user / staff backfill: a one-time data migration or runner script that
calls the digest helper directly, **not** `save`. Saving prematurely would re-encrypt under the
non-deterministic scheme while the lookup path still expects deterministic values.

### Phase 3: Audit customer-side query paths

Find every site that queries `CustomerEmail` or `CustomerTelephone` by encrypted column. Most of
these are in:

- `app/controllers/sign/com/...` (sign-in, OTP, configuration flows for the `:com` IdP host).
- `app/controllers/concerns/sign/com_verification_base.rb` (already known to read
  `current_customer.customer_emails`).
- `app/services/...` for any customer reconciliation services.
- Tests, fixtures, and any rake tasks that touch the customer side.

Replace each lookup with a `*_bidx` / `*_digest` query. Check the audit list into the PR.

### Phase 4: Concern flip (sequenced with the user/staff plan)

This is the load-bearing coordination point with
`plans/backlog/deterministic-encryption-migration-plan.md`. The `Email` and `Telephone` concerns are
shared, so the moment `deterministic: true` is removed in the concern, **both** sides flip.

Sequencing requirement: do not ship the concern flip until:

1. The user/staff plan has reached the same point (its own audit complete, its own `staff_email` /
   `staff_telephone` blind indexes in place).
2. This plan has reached the same point (Phases 0–3 complete).

Then in a single PR (or a tightly sequenced set of PRs):

1. Remove `deterministic: true` from `app/models/concerns/email.rb:22` and
   `app/models/concerns/telephone.rb:20`.
2. Remove `deterministic: true` from `app/models/user_email.rb:85` and
   `app/models/staff_email.rb:72`.
3. Hoist the `set_*_digests` callbacks into the concerns if they have not already been hoisted by
   the user/staff plan.
4. Run `bin/rails db:encryption:reencrypt` against `principal`, `operator`, and `guest` (or
   whichever DB owns customer auth) databases. Plan downtime or a zero-downtime dual-read window up
   front.

### Phase 5: Customer-included key-rotation drill

Re-run the rotation drill described in the umbrella plan with customer included:

1. Sign-in / OTP / verification flows on the `:com` IdP host all succeed.
2. New key takes effect; old key drops.

If the user/staff plan already ran the drill before this plan landed, run it again with customer
rows present so the drill is genuinely end-to-end.

### Phase 6: Cleanup

1. Remove any dual-write scaffolding specific to customer.
2. Drop legacy customer-side columns retained "just in case" only after a deploy cycle confirms the
   new path is solid.
3. If Phase 0 ended up creating a fresh `db/guest_schema.rb`, document in `docs/` (or an ADR) why
   the dump existed in this funky state and what the recovery path is, so the next operator does not
   re-discover it from scratch.

## Risks

- **Phase 0 may surface a bigger problem.** If the customer tables really do not exist in the
  current schema, the customer auth surface is broken at the persistence layer and this plan cannot
  ship until that is fixed. Be prepared to pause.
- **Concern-flip coupling.** Shipping Phase 4 ahead of the user/staff plan, or vice versa, will
  break lookups on the lagging side. The two plans must reach Phase 4 together.
- **`set_address_digests` already wired.** Customer models already have the digest callbacks in
  place. Make sure the backfill (Phase 2) does not double-run them or skip rows where the callback
  failed historically.

## Acceptance Criteria

- [x] Phase 0 resolved: `db/guest_schema.rb` (or the appropriate dump) exists and matches the
      `customer_emails` and `customer_telephones` model annotations.
- [x] Blind-index columns and partial-unique indexes confirmed on `customer_emails` and
      `customer_telephones`.
- [x] Backfill complete; every existing customer email / telephone row has a populated `*_bidx` and
      `*_digest`.
- [x] Customer-side query paths audited and migrated to blind-index lookups (audit list checked in).
- [ ] `deterministic: true` removed from the concerns and per-model overrides, in the same shipping
      window as the user/staff plan.
- [ ] Re-encryption run on the customer-owning database.
- [ ] Key-rotation drill rerun with customer rows present.

## Related

- `plans/backlog/deterministic-encryption-migration-plan.md` — peer plan for user / staff. Phase 4
  here must be sequenced with Phase 3 there.
- `plans/backlog/gh533-encryption-blind-index-migration.md` — GitHub #533 status; references this
  plan as the customer-side counterpart.
