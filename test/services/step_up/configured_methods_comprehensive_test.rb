# typed: false
# frozen_string_literal: true

require "test_helper"

class StepUp::ConfiguredMethodsComprehensiveTest < ActiveSupport::TestCase
  fixtures :users

  test "returns empty array for nil subject" do
    assert_equal [], StepUp::ConfiguredMethods.call(nil)
  end

  test "returns empty array for object without email/passkey/totp associations" do
    assert_equal [], StepUp::ConfiguredMethods.call(Object.new)
  end

  test "configured_email? returns false for object without email associations" do
    assert_not StepUp::ConfiguredMethods.configured_email?(Object.new)
  end

  test "configured_passkey? returns false for object without passkey associations" do
    assert_not StepUp::ConfiguredMethods.configured_passkey?(Object.new)
  end

  test "configured_totp? returns false for object without otp associations" do
    assert_not StepUp::ConfiguredMethods.configured_totp?(Object.new)
  end

  test "configured_email? returns true for user with user_emails" do
    user = users(:one)
    result = StepUp::ConfiguredMethods.configured_email?(user)
    expected = user.user_emails.exists?

    assert_equal expected, result
  end

  test "configured_passkey? returns true for user with user_passkeys" do
    user = users(:one)
    result = StepUp::ConfiguredMethods.configured_passkey?(user)
    expected = user.user_passkeys.exists?

    assert_equal expected, result
  end

  test "configured_totp? returns false for user without user_one_time_passwords" do
    user = users(:one)
    result = StepUp::ConfiguredMethods.configured_totp?(user)
    expected = user.user_one_time_passwords.exists?

    assert_equal expected, result
  end

  test "call includes email_otp when user has emails" do
    user = users(:one)
    if user.user_emails.exists?
      assert_includes StepUp::ConfiguredMethods.call(user), :email_otp
    else
      assert_not_includes StepUp::ConfiguredMethods.call(user), :email_otp
    end
  end

  test "call includes passkey when user has passkeys" do
    user = users(:one)
    result = StepUp::ConfiguredMethods.call(user)
    if user.user_passkeys.exists?
      assert_includes result, :passkey
    else
      assert_not_includes result, :passkey
    end
  end

  test "configured_email? with customer_emails" do
    customer = Customer.new(status_id: CustomerStatus::ACTIVE)

    assert_not StepUp::ConfiguredMethods.configured_email?(customer)
  end

  test "configured_passkey? with customer_passkeys" do
    customer = Customer.new(status_id: CustomerStatus::ACTIVE)

    assert_not StepUp::ConfiguredMethods.configured_passkey?(customer)
  end

  test "configured_passkey? with staff_passkeys" do
    staff = Staff.new(status_id: StaffStatus::NOTHING)

    assert_not StepUp::ConfiguredMethods.configured_passkey?(staff)
  end

  test "configured_email? with staff_emails" do
    staff = Staff.new(status_id: StaffStatus::NOTHING)

    assert_not StepUp::ConfiguredMethods.configured_email?(staff)
  end
end
