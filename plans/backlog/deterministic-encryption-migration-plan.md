# Deterministic Encryption Migration Plan

## Issue

GitHub #533

## Current Status

### Completed

Blind index columns added to the following models:

| Model               | Blind Index Columns                                | Migration      |
| ------------------- | -------------------------------------------------- | -------------- |
| UserEmail           | `address_bidx`, `address_digest`                   | Existing       |
| UserTelephone       | `number_bidx`, `number_digest`                     | Existing       |
| CustomerEmail       | `address_bidx`, `address_digest`                   | Existing       |
| CustomerTelephone   | `number_bidx`, `number_digest`                     | Existing       |
| StaffEmail          | `address_bidx`, `address_digest`                   | 20260414150000 |
| StaffTelephone      | `number_bidx`, `number_digest`                     | Existing       |
| AppContactEmail     | `email_address_bidx`, `email_address_digest`       | 20260414151000 |
| ComContactEmail     | `email_address_bidx`, `email_address_digest`       | 20260414151000 |
| OrgContactEmail     | `email_address_bidx`, `email_address_digest`       | 20260414151000 |
| AppContactTelephone | `telephone_number_bidx`, `telephone_number_digest` | 20260414152000 |
| ComContactTelephone | `telephone_number_bidx`, `telephone_number_digest` | 20260414152000 |
| OrgContactTelephone | `telephone_number_bidx`, `telephone_number_digest` | 20260414152000 |

### Still Using deterministic: true

The following models still use `encrypts :field, deterministic: true`:

| Model               | Field              | Status             |
| ------------------- | ------------------ | ------------------ |
| UserEmail           | `address`          | Needs verification |
| CustomerEmail       | `address`          | Needs verification |
| StaffEmail          | `address`          | Needs verification |
| UserTelephone       | `number`           | Needs verification |
| CustomerTelephone   | `number`           | Needs verification |
| StaffTelephone      | `number`           | Needs verification |
| AppContactEmail     | `email_address`    | Needs verification |
| ComContactEmail     | `email_address`    | Needs verification |
| OrgContactEmail     | `email_address`    | Needs verification |
| AppContactTelephone | `telephone_number` | Needs verification |
| ComContactTelephone | `telephone_number` | Needs verification |
| OrgContactTelephone | `telephone_number` | Needs verification |
| Telephone concern   | `number`           | Needs verification |

## Migration Strategy

### Phase 1: Verification (Current)

1. Verify all blind index columns are properly populated
2. Ensure uniqueness constraints are working
3. Confirm query paths use blind indexes where appropriate

### Phase 2: Query Path Migration

1. Identify all query paths using encrypted columns with deterministic search
2. Migrate queries to use blind index columns (`*_bidx` or `*_digest`)
3. Update scopes and finder methods

### Phase 3: Deterministic Removal

After all query paths are migrated:

1. Remove `deterministic: true` from encrypts declarations
2. Run `bin/rails db:encryption:reencrypt` to re-encrypt with non-deterministic mode
3. Verify no application code relies on deterministic encryption

### Phase 4: Cleanup

1. Remove backward compatibility code in `set_*_digests` methods
2. Consider dropping legacy columns if no longer needed

## Risks

- Query paths may still rely on deterministic encryption for lookups
- External integrations may depend on deterministic encrypted values
- Re-encryption requires downtime or careful zero-downtime migration

## Acceptance Criteria

- [ ] All query paths migrated to blind indexes
- [ ] `deterministic: true` removed from all encrypts declarations
- [ ] Database re-encrypted with non-deterministic mode
- [ ] No regression in lookup functionality
- [ ] Performance validated (blind index lookups vs deterministic)
