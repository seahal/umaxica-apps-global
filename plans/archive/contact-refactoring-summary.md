# Corporate Site Contact Refactoring Summary

## Overview

This document summarizes the refactoring work done to implement a proper contact intake flow for the
corporate site.

## Changes Made

### 1. Fixed Typo: Telepyhone → Telephone ✅

**Files affected:**

- Renamed: `app/models/corporate_site_contact_telepyhone.rb` →
  `app/models/corporate_site_contact_telephone.rb`
- Updated class name: `CorporateSiteContactTelepyhone` → `CorporateSiteContactTelephone`
- Renamed: `test/models/corporate_site_contact_telepyhone_test.rb` →
  `test/models/corporate_site_contact_telephone_test.rb`
- Updated all test references
- Renamed: `test/fixtures/corporate_site_contact_telepyhones.yml` →
  `test/fixtures/corporate_site_contact_telephones.yml`
- Updated documentation in `plans/archive/contact-refactoring-analysis.md`

**Migration:**

- Created `db/guests_migrate/20251027110000_rename_telepyhones_to_telephones.rb`

### 2. Fixed Wrong Regex in Telephone Concern ✅

**File:** `app/models/concerns/telephone.rb`

**Changed from:**

```ruby
format: { with: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i }  # Email regex!
```

**Changed to:**

```ruby
format: { with: /\A\+?[\d\s\-\(\)]+\z/, message: "must be a valid phone number" }
```

This now properly validates phone numbers instead of email addresses.

### 3. Added Verification Columns ✅

**Migration:** `db/guests_migrate/20251027110100_add_verification_fields_to_contacts.rb`

**Added to `corporate_site_contact_emails`:**

- `verifier_digest` (string, 255) - Hashed email verification code
- `verifier_expires_at` (timestamptz) - When the code expires
- `verifier_attempts_left` (integer, default: 3) - Remaining verification attempts

**Added to `corporate_site_contact_telephones`:**

- `otp_digest` (string, 255) - Hashed OTP code
- `otp_expires_at` (timestamptz) - When the OTP expires
- `otp_attempts_left` (integer, default: 3) - Remaining OTP attempts

**Added to `corporate_site_contacts`:**

- `token_digest` (string, 255) - Hashed final one-time token
- `token_expires_at` (timestamptz) - When the token expires
- `token_viewed` (boolean, default: false) - Whether token has been viewed

### 4. Implemented State Machine ✅

**File:** `app/models/corporate_site_contact.rb`

**State flow:**

```
email_pending → email_verified → phone_verified → completed
```

**Features added:**

- Rails enum for `status` with 4 states
- Rails enum for `category` (general, inquiry, support, sales, partnership, other)
- State transition methods: `verify_email!`, `verify_phone!`, `complete!`
- State check methods: `can_verify_email?`, `can_verify_phone?`, `can_complete?`
- Token management: `generate_final_token`, `verify_token(raw_token)`
- Associations: `has_many :corporate_site_contact_emails`,
  `has_many :corporate_site_contact_telephones`, `has_many :corporate_site_contact_topics`

### 5. Added Verification Logic to Models ✅

**File:** `app/models/corporate_site_contact_email.rb`

Methods added:

- `generate_verifier!` - Creates 6-digit code, stores hash, returns raw code
- `verify_code(raw_code)` - Verifies code, decrements attempts
- `verifier_expired?` - Checks if verifier has expired
- `can_resend_verifier?` - Checks if new verifier can be sent

**File:** `app/models/corporate_site_contact_telephone.rb`

Methods added:

- `generate_otp!` - Creates 6-digit OTP, stores hash, returns raw OTP
- `verify_otp(raw_otp)` - Verifies OTP, decrements attempts
- `otp_expired?` - Checks if OTP has expired
- `can_resend_otp?` - Checks if new OTP can be sent

### 6. Fixed Topic Model Bug ✅

**Issue:** `corporate_site_contact_topics` table had self-referential foreign key

**Files affected:**

- `app/models/corporate_site_contact_topic.rb` - Fixed `belongs_to` association
- Created migration:
  `db/guests_migrate/20251027110200_fix_corporate_site_contact_topics_foreign_key.rb`

### 7. Updated Tests and Fixtures ✅

**Updated fixtures:**

- `test/fixtures/corporate_site_contacts.yml` - Changed status from "active" to valid enum values

**Updated tests:**

- `test/models/corporate_site_contact_test.rb` - Added comprehensive state machine tests
- `test/models/corporate_site_contact_telephone_test.rb` - Updated class references

**New test coverage:**

- State transitions
- Token generation and verification
- Enum validation
- Default values

## Security Improvements

1. **No raw secrets stored** - All codes/tokens are hashed with Argon2
2. **Time-bound verification** - Codes expire after 10-15 minutes
3. **Attempt limiting** - Max 3 attempts before needing new code
4. **One-time token semantics** - Token can only be viewed once
5. **Encrypted PII** - Email and phone stored with deterministic encryption

## Architecture Patterns

- **State Machine**: Rails enum with explicit transitions
- **Verification**: Argon2 hashing, time-based expiry, attempt limiting
- **Associations**: Clean ActiveRecord relationships
- **Testing**: Minitest with comprehensive coverage

## Next Steps (Not Yet Implemented)

1. **Service Layer**: Create `ContactEmailVerifier`, `ContactPhoneVerifier`, `ContactTokenIssuer`
   service objects
2. **Rate Limiting**: Implement Rack::Attack for IP/email/phone throttling
3. **Controllers**: Build controllers for the top/com domain (formerly www/com)
4. **Mailers**: Create email verification mailer
5. **SMS Integration**: Wire up OTP sending via existing AwsSmsService
6. **Anti-abuse**: Add Turnstile/reCAPTCHA verification
7. **Routes**: Define the 8-step contact flow routes

## Migration Order

To apply these changes:

```bash
# Run migrations for guest database
bundle exec rails db:migrate:guest

# Or run all database migrations
bundle exec rails db:migrate

# Run tests
bundle exec rails test
```

## Files Modified

### Models

- `app/models/corporate_site_contact.rb`
- `app/models/corporate_site_contact_email.rb`
- `app/models/corporate_site_contact_telephone.rb` (renamed from telepyhone)
- `app/models/corporate_site_contact_topic.rb`
- `app/models/concerns/telephone.rb`

### Tests

- `test/models/corporate_site_contact_test.rb`
- `test/models/corporate_site_contact_telephone_test.rb` (renamed)

### Fixtures

- `test/fixtures/corporate_site_contacts.yml`
- `test/fixtures/corporate_site_contact_telephones.yml` (renamed)

### Migrations

- `db/guests_migrate/20251027110000_rename_telepyhones_to_telephones.rb` (NEW)
- `db/guests_migrate/20251027110100_add_verification_fields_to_contacts.rb` (NEW)
- `db/guests_migrate/20251027110200_fix_corporate_site_contact_topics_foreign_key.rb` (NEW)

### Documentation

- `plans/archive/contact-refactoring-analysis.md` (updated)
- `plans/archive/contact-refactoring-summary.md` (NEW)

## Verification

All changes follow existing codebase patterns:

- ✅ Using `GuestRecord` base class
- ✅ Using Argon2 for password hashing
- ✅ Using ActiveRecord encryption with deterministic mode
- ✅ Using Minitest for testing
- ✅ Using class-method services pattern (to be implemented in controllers)
- ✅ Using UUID primary keys
- ✅ Using timestamptz for time fields
