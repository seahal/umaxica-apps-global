# ADR: Email OTP Race Condition Fixes

**Status:** Accepted

## Context

Two race conditions were identified in the `Email` concern (`app/models/concerns/email.rb`) and the
`EmailRegistrable` concern (`engines/signature/app/controllers/concerns/sign/email_registrable.rb`).

### Race condition 1: Non-atomic OTP attempt increment

`increment_attempts!` used a read-then-write pattern:

```ruby
record = self.class.find(id)
record.update!(otp_attempts_count: otp_attempts_count + 1, ...)
```

Two concurrent requests could both read the same `otp_attempts_count` value and write the same
incremented value, meaning two failed OTP attempts would only register as one. Under
`MAX_OTP_ATTEMPTS = 3`, an attacker could make more attempts than the lock threshold allows before
the lock fires.

A second non-atomic step followed: the lock check loaded matching rows into memory with `.to_a`,
then called `update!` on each — two threads could both pass the threshold check before either wrote
`locked_at`.

### Race condition 2: OTP cooldown check outside transaction

`initiate_email_verification!` checked `otp_cooldown_active?` before opening a transaction:

```ruby
if existing_email.otp_cooldown_active?
  return :cooldown
end

UserEmail.transaction do
  @user_email.otp_last_sent_at = Time.current
  @user_email.save!
  send_verification_email(num)
end
```

Two concurrent signup requests for the same address could both pass the cooldown check before either
set `otp_last_sent_at`, resulting in two OTP emails being sent within the cooldown window.

## Decision

### Fix 1: Atomic increment with `update_all`

Replace the read-then-write pattern with a single SQL `UPDATE` that increments at the database
level, and follow it with a second `update_all` for the lock condition:

```ruby
def increment_attempts!
  self.class.where(id: id).update_all(
    "otp_attempts_count = otp_attempts_count + 1, updated_at = NOW()"
  )
  reload

  self.class.where(id: id)
    .where(
      "locked_at IS NULL OR locked_at = '-infinity'::timestamp OR locked_at = 'infinity'::timestamp"
    )
    .where(otp_attempts_count: MAX_OTP_ATTEMPTS..)
    .update_all(locked_at: Time.current)

  reload
end
```

Both operations are now database-level and do not depend on in-memory state read before the update.

### Fix 2: Cooldown check inside transaction with row lock

Move the definitive cooldown check inside the transaction, using `lock` (i.e.,
`SELECT ... FOR UPDATE`) to prevent concurrent requests from passing the check simultaneously:

```ruby
cooldown_active = false
UserEmail.transaction do
  if existing_email
    locked = UserEmail.lock.find_by(id: existing_email.id)
    if locked&.otp_cooldown_active?
      cooldown_active = true
      raise ActiveRecord::Rollback
    end
  end

  # ... save and send OTP ...
end

return :cooldown if cooldown_active
```

The pre-transaction check is retained as a fast path to avoid acquiring a lock on every request. The
in-transaction check is the authoritative gate.

## Trade-offs

- `update_all` bypasses ActiveRecord callbacks and validations. This is intentional: the increment
  and lock operations must not trigger validation side-effects.
- `SELECT ... FOR UPDATE` on the email row serializes concurrent signup requests for the same
  address. This is the correct behavior and the performance impact is negligible for a per-user row.
- The pre-transaction cooldown check is a best-effort optimization only. The in-transaction check is
  the authoritative one.

## Affected Files

- `app/models/concerns/email.rb` — `increment_attempts!`
- `engines/signature/app/controllers/concerns/sign/email_registrable.rb` —
  `initiate_email_verification!`
