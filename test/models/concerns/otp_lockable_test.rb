# typed: false
# frozen_string_literal: true

require "test_helper"

# OtpLockable centralizes the OTP attempt/lock/expiry mechanics shared by the
# Email and Telephone concerns. The Email and Telephone concern tests already
# exercise the mechanics in depth through their real models; these tests pin the
# cross-channel invariants and the asymmetries that were normalized when the
# logic was unified:
#   - the unlocked sentinel is "-infinity" for both channels
#   - increment_attempts! never runs model validations (save!(validate: false))
#   - cooldown stays email-only (telephone lacks otp_last_sent_at), which the
#     OTP resend ceremony relies on via respond_to?(:otp_cooldown_active?)
class OtpLockableTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses, :operators, :operator_statuses

  test "both Email and Telephone include OtpLockable" do
    assert_includes ClientEmail.included_modules, OtpLockable
    assert_includes OperatorTelephone.included_modules, OtpLockable
  end

  test "clear_otp leaves an email unlocked through the shared sentinel" do
    email = ClientEmail.create!(
      user: clients(:none_user),
      address: "lockable@example.com",
      confirm_policy: true,
    )
    email.update!(locked_at: 1.minute.from_now, otp_attempts_count: OtpLockable::MAX_OTP_ATTEMPTS)

    email.clear_otp

    assert_not email.locked?
    assert_nil email.lockout_expires_at
  end

  test "clear_otp leaves a telephone unlocked through the shared sentinel" do
    telephone = OperatorTelephone.new(number: "+819012345678", staff: operators(:none_staff))
    telephone.save!(validate: false)
    telephone.update!(locked_at: 1.minute.from_now, otp_attempts_count: OtpLockable::MAX_OTP_ATTEMPTS)

    telephone.clear_otp

    assert_not telephone.locked?
    assert_nil telephone.lockout_expires_at
  end

  test "increment_attempts! does not run model validations" do
    # confirm_policy: false makes the record fail acceptance validation, so a
    # plain save! would raise. increment_attempts! must still succeed.
    telephone = OperatorTelephone.new(
      number: "+819012345678",
      staff: operators(:none_staff),
      confirm_policy: false,
    )
    telephone.save!(validate: false)

    assert_not telephone.valid?, "fixture should be invalid so the validate: false path is meaningful"

    # valid? dirties in-memory attributes (e.g. number_digest); discard them so
    # the row lock in increment_attempts! sees a clean persisted record.
    telephone.reload

    assert_nothing_raised { telephone.increment_attempts! }
    assert_equal 1, telephone.reload.otp_attempts_count
  end

  test "cooldown stays email-only so the resend ceremony branch is preserved" do
    assert_respond_to ClientEmail.new(user: clients(:none_user)), :otp_cooldown_active?
    assert_not OperatorTelephone.new(staff: operators(:none_staff)).respond_to?(:otp_cooldown_active?)
  end
end
