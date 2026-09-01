# typed: false
# frozen_string_literal: true

require "test_helper"

# Starting an email registration writes an account and a pending address in one
# go. A rejected write must come back as a failed attempt carrying the rejected
# record, so the form can re-render with its errors rather than the request
# ending in an exception.
class SignEmailRegistrableFailureTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness
    include SignEmailRegistrable

    attr_accessor :turnstile_ok

    def initialize = @turnstile_ok = true

    def ensure_signup_reference_defaults! = nil

    def ensure_turnstile!(_address, _confirm_policy) = turnstile_ok

    def build_user_email(address, confirm_policy, _preferences = {})
      @user_email = ClientEmail.new(raw_address: address, confirm_policy: confirm_policy)
    end

    def pending_email_status_id = ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP

    def create_and_send_verified_email!(_allow_existing)
      rejected = ClientEmail.new
      rejected.errors.add(:address, :taken)
      raise ActiveRecord::RecordInvalid, rejected
    end

    def user_email = @user_email

    def invoke(name, ...) = send(name, ...)
  end

  setup do
    @harness = Harness.new
  end

  test "a rejected write comes back as a failed attempt carrying the rejected record" do
    assert_not @harness.invoke(:initiate_email_verification!, "someone@example.com")
    assert_includes @harness.user_email.errors.attribute_names, :address
  end

  test "a failed stealth challenge stops before anything is written" do
    @harness.turnstile_ok = false

    assert_not @harness.invoke(:initiate_email_verification!, "someone@example.com")
  end
end
