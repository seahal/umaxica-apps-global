# Retainable Concern and Retention Purge Design

## situation

Accepted

## context

Applications require retention management in many models, but the current challenges include:

1. The columns representing physical deletion time are `deletable_at`, `shreddable_at`,
   `scheduled_purge_at` etc., and are not unified.
2. Columns representing logical deletion time also include `revoked_at`, `expires_at`,
   `refresh_expires_at`, `compromised_at` There are multiple such as
3. Each model manages these columns differently and is inconsistent

## decision

### Column unification

1. **`discarded_at`** - Logical deletion time (time when access becomes impossible)
2. **`purged_at`** - Physical deletion candidate time (time when data can actually be deleted)

`discarded_at` is the standard column name for the `discard` gem, so `self.discard_column = ...` for
each model. Not set. In this migration, in order to maintain the time window semantics of the
existing Retainable, `discarded_at = Float::INFINITY` equivalent to unrevoked sentinel,
`discarded_at <= Time.current` be treated as inaccessible. discard gem `NULL = kept` Switching to
semantics is a separate task after the time window usage has been separated into separate columns.

### Introducing Retainable Concern

Use `Retainable` concern, which is common to all models, to centrally manage the above two columns.

```ruby
module Retainable
  extend ActiveSupport::Concern

  SENTINEL = ::Float::INFINITY

  included do
    attribute :discarded_at, :datetime, default: -> { SENTINEL }
    attribute :purged_at, :datetime, default: -> { SENTINEL }

    validates :discarded_at, presence: true
    validates :purged_at, presence: true
    validate :discarded_at_not_after_purged_at
    validate :retention_times_not_before_created_at, on: :update
  end

  def accessible?
    discarded_at > Time.current
  end

  def lapsed?
    discarded_at <= Time.current
  end

  def purgeable?
    purged_at <= Time.current
  end

  def schedule_retention!(discarded_at:, purged_at:)
    raise ArgumentError, 'discarded_at must be in the future' if discarded_at <= Time.current
    raise ArgumentError, 'purged_at must be in the future' if purged_at <= Time.current
    raise ArgumentError, 'discarded_at must be <= purged_at' if discarded_at > purged_at
    update!(discarded_at: discarded_at, purged_at: purged_at)
  end
end
```

### Consolidated map of columns

#### Columns to be integrated into `discarded_at`

- `revoked_at`
- `expires_at` (credential variant)
- `refresh_expires_at`
- `compromised_at`

#### Columns to be integrated into `purged_at`

- `deletable_at`
- `shreddable_at`
- `scheduled_purge_at`
- `expires_at` (audit/chronicle variant)

#### Column to delete

- `expired_at` (user_token, customer_token)

#### Column to be deferred (sub-state column)

- `token_expires_at`
- `verifier_expires_at` / `otp_expires_at`
- `expires_at` (token only: user/staff/customer_token)
- `consumed_at`
- `used_at`

### Solid Queue retention job

Create a RetentionPurgeJob to periodically delete records that are `purged_at` old.

```ruby
class RetentionPurgeJob < ApplicationJob
  queue_as :retention

  RETAINABLE_MODELS = [
    User, Customer, Staff, AppPreference, OrgPreference, ComPreference,
    UserToken, OperatorToken, CustomerToken,
    UserVerification, OperatorVerification, CustomerVerification,
    UserAuthorizationCode, OperatorAuthorizationCode, CustomerAuthorizationCode,
    ClientStepUpSession, OperatorStepUpSession, VisitorStepUpSession,
    AreaOccurrence, UserOccurrence, OperatorOccurrence, ZipOccurrence,
    DomainOccurrence, IpOccurrence, EmailOccurrence, JwtOccurrence, TelephoneOccurrence,
    AppJumpLink, ComJumpLink, OrgJumpLink
  ].freeze

  def perform(batch_size: 500)
    now = Time.current
    RETAINABLE_MODELS.each do |klass|
      klass.where('purged_at <= ?', now).in_batches(of: batch_size).delete_all
    end
  end
end
```

## reason

1. By unifying columns, the complexity of retention management is significantly reduced.
2. `discarded_at` is a standard column name for the `discard` gem, making
   `self.discard_column = ...` unnecessary
3. `Retainable` concern provides consistent interface across all models
4. Efficiently perform physical deletion processing with Solid Queue job
5. `discarded_at` / `purged_at` is `Float::INFINITY` can be used as the sentinel value to simplify
   the query while preserving the existing time window semantics.

## influence

- Column name change and data migration required for models with 24 or more
- Change references in existing controllers and services to new column names
- The test code also needs to be adapted to the new column names.
- The existing implementation `lapses_at` will be migrated to `discarded_at`
- As a migration strategy, rename existing columns to `discarded_at` / `purged_at`
