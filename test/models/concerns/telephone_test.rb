# typed: false
# frozen_string_literal: true

require "test_helper"

class TelephoneConcernTest < ActiveSupport::TestCase
  fixtures :operators, :operator_statuses

  setup do
    @telephone = OperatorTelephone.new(
      number: "+1234567890",
      staff: operators(:none_staff),
    )
    @telephone.save!(validate: false)
  end

  test "store_otp updates otp fields" do
    expires_at = 5.minutes.from_now.to_i
    @telephone.store_otp("secret_credential", 123, expires_at)

    assert_equal "secret_credential", @telephone.otp_private_key
    assert_equal "123", @telephone.otp_counter
    assert_equal Time.zone.at(expires_at), @telephone.otp_expires_at
    assert_equal 0, @telephone.otp_attempts_count
    # unlocked sentinel
    locked = @telephone.locked_at

    assert locked.nil? || locked.to_s == "-infinity" || (locked.is_a?(Float) && locked == -Float::INFINITY)
  end

  test "store_otp does not clear active lockout" do
    lockout_expires_at = 10.minutes.from_now
    @telephone.update!(
      locked_at: lockout_expires_at,
      otp_attempts_count: Telephone::MAX_OTP_ATTEMPTS,
    )

    @telephone.store_otp("secret_credential", 123, 5.minutes.from_now.to_i)

    assert_equal Telephone::MAX_OTP_ATTEMPTS, @telephone.reload.otp_attempts_count
    assert_equal lockout_expires_at.to_i, @telephone.locked_at.to_i
    assert_predicate @telephone, :locked?
  end

  test "get_otp returns otp details if valid" do
    expires_at = 5.minutes.from_now.to_i
    @telephone.store_otp("secret_credential", 123, expires_at)

    otp = @telephone.get_otp

    assert_equal "secret_credential", otp[:otp_private_key]
    assert_equal 123, otp[:otp_counter]
    assert_equal expires_at, otp[:otp_expires_at]
  end

  test "get_otp returns nil if otp_private_key is blank" do
    @telephone.otp_private_key = ""
    @telephone.save!(validate: false) # Use empty string as DB requires not null

    assert_nil @telephone.get_otp
  end

  test "get_otp returns nil if otp expired" do
    @telephone.store_otp("secret_credential", 123, 5.minutes.ago.to_i)

    assert_nil @telephone.get_otp
  end

  test "get_otp returns nil if locked" do
    @telephone.store_otp("secret_credential", 123, 5.minutes.from_now.to_i)
    @telephone.update!(locked_at: 1.minute.from_now)

    assert_nil @telephone.get_otp
  end

  test "clear_otp clears otp fields" do
    @telephone.store_otp("secret_credential", 123, 5.minutes.from_now.to_i)
    @telephone.clear_otp

    assert_equal "secret_credential", @telephone.otp_private_key # Persists
    assert_equal "0", @telephone.otp_counter
    # Expect -infinity logic
    expires = @telephone.otp_expires_at

    assert expires.nil? || expires.to_s == "-infinity" || (expires.is_a?(Float) && expires == -Float::INFINITY)

    assert_equal 0, @telephone.otp_attempts_count

    locked = @telephone.locked_at

    assert locked.nil? || locked.to_s == "-infinity" || (locked.is_a?(Float) && locked == -Float::INFINITY)
  end

  test "otp_expired? returns true if expired or nil" do
    @telephone.update!(otp_expires_at: "-infinity") # Use sentinel

    assert_predicate @telephone, :otp_expired?

    @telephone.update!(otp_expires_at: 5.minutes.ago)

    assert_predicate @telephone, :otp_expired?

    @telephone.update!(otp_expires_at: 5.minutes.from_now)

    assert_not @telephone.otp_expired?
  end

  test "otp_active? returns true if not expired and not locked" do
    @telephone.store_otp("secret_credential", 123, 5.minutes.from_now.to_i)

    assert_predicate @telephone, :otp_active?

    @telephone.update!(locked_at: 1.minute.from_now)

    assert_not @telephone.otp_active?

    @telephone.update!(locked_at: "-infinity", otp_expires_at: 5.minutes.ago)

    assert_not @telephone.otp_active?
  end

  test "locked? returns true if lockout active or attempts exceeded in window" do
    assert_not @telephone.locked?

    @telephone.update!(locked_at: 1.minute.from_now)

    assert_predicate @telephone, :locked?

    @telephone.update!(locked_at: "-infinity", otp_attempts_count: Telephone::MAX_OTP_ATTEMPTS)

    assert_predicate @telephone, :locked?
  end

  test "increment_attempts! increments counter and locks if threshold reached" do
    @telephone.store_otp("secret_credential", 123, 5.minutes.from_now.to_i)

    (Telephone::MAX_OTP_ATTEMPTS - 1).times do |index|
      @telephone.increment_attempts!

      assert_equal index + 1, @telephone.otp_attempts_count
      assert_not @telephone.locked?
    end

    @telephone.increment_attempts!

    assert_equal Telephone::MAX_OTP_ATTEMPTS, @telephone.otp_attempts_count
    assert_predicate @telephone, :locked?
    assert_not_nil @telephone.locked_at
  end

  test "increment_attempts! sets locked_at timestamp when threshold is reached" do
    @telephone.store_otp("secret_credential", 123, 5.minutes.from_now.to_i)

    # Initially locked_at should be a sentinel (-infinity)
    locked = @telephone.locked_at

    assert locked.nil? || locked.to_s == "-infinity" || (locked.is_a?(Float) && locked == -Float::INFINITY)

    Telephone::MAX_OTP_ATTEMPTS.times { @telephone.increment_attempts! }
    @telephone.reload

    assert_predicate @telephone.locked_at, :present?
    assert_not_equal @telephone.locked_at, -Float::INFINITY
    assert_operator @telephone.locked_at, :>, Time.current
    assert_operator @telephone.locked_at, :<=, Telephone::OTP_LOCKOUT_DURATION.from_now
  end

  test "increment_attempts! keeps locked_at stable when incrementing beyond threshold" do
    @telephone.store_otp("secret_credential", 123, 5.minutes.from_now.to_i)

    Telephone::MAX_OTP_ATTEMPTS.times { @telephone.increment_attempts! }
    @telephone.reload

    first_locked_at = @telephone.locked_at

    assert_predicate first_locked_at, :present?
    assert_not_equal first_locked_at, -Float::INFINITY

    # Increment again beyond threshold
    @telephone.increment_attempts!
    @telephone.reload

    # locked_at should remain the same (idempotent)
    assert_equal first_locked_at.to_i, @telephone.locked_at.to_i
  end

  test "increment_attempts! does not change locked_at if already set" do
    initial_lock_time = 1.hour.from_now
    @telephone.update!(locked_at: initial_lock_time, otp_attempts_count: Telephone::MAX_OTP_ATTEMPTS)

    # Increment again
    @telephone.increment_attempts!
    @telephone.reload

    # locked_at should remain unchanged (idempotent)
    assert_equal initial_lock_time.to_i, @telephone.locked_at.to_i
  end

  test "locked? returns false after lockout expires" do
    @telephone.update!(locked_at: 1.second.ago, otp_attempts_count: Telephone::MAX_OTP_ATTEMPTS)

    assert_not @telephone.locked?
  end

  test "attempts outside observation window reset before lockout" do
    @telephone.update!(
      otp_attempts_count: Telephone::MAX_OTP_ATTEMPTS - 1,
      created_at: (Telephone::OTP_ATTEMPT_WINDOW + 1.second).ago,
    )

    @telephone.increment_attempts!

    assert_equal 1, @telephone.reload.otp_attempts_count
    assert_not @telephone.locked?
  end

  test "validate_number_format adds specific error for country code" do
    zero_country = OperatorTelephone.new(number: "+0123456789", staff: operators(:none_staff))

    assert_not zero_country.valid?
    assert_includes zero_country.errors.details[:number].pluck(:error),
                    :country_code_cannot_start_with_zero
  end

  test "reregistration_window_active? uses independent ten second window" do
    @telephone.update!(created_at: 9.seconds.ago)

    assert_predicate @telephone, :reregistration_window_active?

    @telephone.update!(created_at: 11.seconds.ago)

    assert_not @telephone.reregistration_window_active?
  end
end
