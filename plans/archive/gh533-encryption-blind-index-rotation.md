# GH-533: Email/Telephone Encryption Key Rotation via Blind-Index Lookup

GitHub: #533

## Status

**Implemented 2026-05-10.** Replaces the earlier umbrella draft so that key rotation is no longer
indefinitely deferred.

## Goal

Make `Email` and `Telephone` columns re-keyable. Today they cannot be rotated because the shared
concerns declare `encrypts ..., deterministic: true`, which freezes the column to its current
`ActiveRecord::Encryption.deterministic_key`.

## Approach (User-confirmed 2026-05-09)

Stay with the **same-table blind-index** strategy: keep email/telephone on the existing `*_emails` /
`*_telephones` tables, add `*_bidx` and `*_digest` columns for searches, and remove the
`deterministic: true` flag. **Do not introduce a separate Identity table.**

## Implementation Pattern (Rails idiom)

How this is wired in Rails — **model-layer only, no controller-side digest computation**:

- **`before_validation` callback** on the model writes the HMAC into `*_bidx` / `*_digest`. The
  existing `UserEmail#set_address_digests` (`app/models/user_email.rb:115-119`) is the template.
  Hoist it into the shared concerns once Customer side is sequenced.
- **Class methods / scopes** wrap the digest-based lookup. Example:

  ```ruby
  # app/models/concerns/email.rb
  class << self
    def find_by_address(value)
      digest = IdentifierBlindIndex.bidx_for_email(value)
      return nil if digest.blank?
      find_by(address_digest: digest)
    end
  end
  ```

- **Controllers stay simple**: `UserEmail.find_by_address(params[:email])`. No HMAC code in
  controllers. (`Sign::TelephoneRegistrable#initiate_telephone_verification` already does this for
  telephone via `IdentifierBlindIndex.bidx_for_telephone` at
  `app/controllers/concerns/sign/telephone_registrable.rb:25-26` — same pattern for email.)

## Current State (verified 2026-05-10)

### Blind-index columns

| Model                | DB        | `*_bidx` / `*_digest` |
| -------------------- | --------- | --------------------- |
| `user_email`         | principal | ✅ present            |
| `user_telephone`     | principal | ✅ present            |
| `staff_email`        | operator  | ✅ present            |
| `staff_telephone`    | operator  | ✅ present            |
| `customer_email`     | guest     | ✅ present            |
| `customer_telephone` | guest     | ✅ present            |

### `deterministic: true` declarations in scope

No remaining `deterministic: true` declarations exist on the auth identifier models covered by this
plan. The only remaining deterministic email/telephone attributes are contact mirror models
(`*_contact_*`), which are out of scope for GH-533.

## Sequenced Steps

Each step ships independently and has its own rollback story.

1. **Staff schema parity.** Complete. Added `address_bidx`, `address_digest`, `number_bidx`,
   `number_digest` columns and partial-unique indexes (`WHERE *_bidx IS NOT NULL`) to `staff_emails`
   and `staff_telephones` (`db/operators_migrate/`). Mirror the user-side shape exactly.

2. **Backfill.** Complete. Recompute `IdentifierBlindIndex` for every existing user and staff row
   via a runner script or data migration — **not via `save`**, because doing so would prematurely
   rewrite the encrypted column under non-deterministic mode while lookups still rely on
   deterministic.

3. **Query path migration audit.** Complete. Find every place that queries `user_email`,
   `user_telephone`, `staff_email`, or `staff_telephone` by encrypted value (sign-in, OTP, admin
   search, rake tasks, tests). Switch each to `*_bidx` / `*_digest` lookups via the class method
   described above. **Check the audit list into the PR** so re-auditing later is not necessary.

   Audit trail, 2026-05-09:
   - `app/models/concerns/email.rb`
   - `app/models/concerns/telephone.rb`
   - `app/controllers/concerns/sign/email_registrable.rb`
   - `app/controllers/concerns/sign/telephone_registrable.rb`
   - `app/controllers/sign/org/preference/emails_controller.rb`
   - `app/controllers/sign/org/auth/omniauth_callbacks_controller.rb`
   - `app/controllers/sign/app/up/telephones_controller.rb`
   - `app/services/sign/in/otp_resend_service.rb`
   - `test/models/user_email_test.rb`
   - `test/models/user_telephone_test.rb`
   - `test/models/staff_email_test.rb`
   - `test/models/staff_telephone_test.rb`
   - `test/integration/identifier_encryption_rotation_drill_test.rb`
   - `test/controllers/sign/app/settings/emails/registrations_controller_test.rb`
   - `test/controllers/sign/app/in/emails_controller_security_test.rb`
   - `test/controllers/sign/org/settings/emails/registrations_controller_test.rb`

4. **Switch off `deterministic: true`.** Complete. Removed the flag from auth email/telephone
   identifier encryption and hoisted `set_*_digests` callbacks into the shared concerns so user /
   staff / customer share the same digest pipeline.

5. **Re-encrypt.** Supported by code and tested. Run `bin/rails db:encryption:reencrypt` (or a
   zero-downtime equivalent) on both principal and operator databases so existing ciphertext is
   rewritten under the non-deterministic scheme. This repo now provides `db:encryption:reencrypt`
   backed by `IdentifierEncryptionReencrypt` for user / staff / customer rows.

6. **Key-rotation drill.** Covered by automated integration test. Add a new key, re-encrypt, drop
   the old key, prove sign-in / OTP / sign-up work end-to-end on every surface (`app`, `org`,
   `com`). This is the actual reason this migration exists; do not skip.

## Existing Infrastructure

- `app/services/identifier_blind_index.rb` — HMAC-SHA256 with `IDENTIFIER_BIDX_SECRET` credential.
  Provides `bidx_for_email` and `bidx_for_telephone`.
- Shared callbacks in `app/models/concerns/email.rb` and `app/models/concerns/telephone.rb` populate
  `*_bidx` and `*_digest`.
- `Sign::TelephoneRegistrable#initiate_telephone_verification` already uses the blind-index lookup
  pattern (`app/controllers/concerns/sign/telephone_registrable.rb:25-43`).

## Critical Files

- `app/models/concerns/email.rb`, `app/models/concerns/telephone.rb`
- `app/models/user_email.rb`, `app/models/staff_email.rb`, `app/models/customer_email.rb` plus
  telephone counterparts.
- `app/services/identifier_blind_index.rb`
- `db/operators_migrate/` — new migrations for staff side.
- `plans/backlog/customer-email-telephone-encryption-plan.md` — must sequence with step 4.

## Verification

- Per-model test that the digest callback fires and produces a stable HMAC.
- Per-model test that the `find_by_address` / `find_by_number` class methods return the same record
  after re-encryption with a new key.
- Rotation drill in dev: two-key generation rotation completes with sign-in, OTP, sign-up passing
  across `app`, `org`, `com` surfaces.

2026-05-10 verification:

- `bin/rails test test/models/user_email_test.rb test/models/user_telephone_test.rb test/models/staff_email_test.rb test/models/staff_telephone_test.rb test/models/customer_email_test.rb test/models/customer_telephone_test.rb test/services/identifier_blind_index_backfill_test.rb test/services/identifier_encryption_reencrypt_test.rb test/integration/identifier_encryption_rotation_drill_test.rb test/controllers/sign/org/settings/emails/registrations_controller_test.rb test/controllers/sign/app/settings/emails/registrations_controller_test.rb test/controllers/sign/app/in/emails_controller_security_test.rb`
  passed: 122 runs, 338 assertions.

## Related

- `plans/backlog/customer-email-telephone-encryption-plan.md` — must complete in lockstep with
  step 4.
- `plans/backlog/deterministic-encryption-migration-plan.md` — umbrella; keep in sync.
- `adr/reference-table-discipline.md` — Identity-table option was considered and rejected; this plan
  stays on same-table blind index.
