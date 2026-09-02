# typed: false
# frozen_string_literal: true

require "test_helper"

# The sign-up confirmation link carries a verification token alongside the code.
# When one is supplied it is checked strictly: a token that does not verify has
# to stop the confirmation with an error on the record, because accepting it
# would let a link addressed to one registration confirm another.
class SignEmailRegistrableVerificationTokenTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness
    include SignEmailRegistrable

    def t(key, **) = key.to_s

    def invoke(name, ...) = send(name, ...)

    def user_email = @user_email
  end

  setup do
    @harness = Harness.new
    @user = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP, visibility_id: ClientVisibility::USER)
    @email = ClientEmail.create!(
      user: @user,
      address: "registrable-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
      otp_private_key: ROTP::Base32.random_base32,
      otp_counter: "0",
    )
  end

  test "a verification token that does not verify stops the confirmation with an error" do
    assert_not @harness.invoke(:complete_email_verification!, @email.public_id, "123456", "not-the-token")

    assert_includes @harness.user_email.errors.full_messages.join(" "),
                    "sign.app.registration.email.update.invalid_token"
  end
end
