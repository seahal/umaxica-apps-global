# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class VisitorIdentityTest < ActiveSupport::TestCase
  setup do
    Prosopite.pause do
      VisitorMultiFactor.ensure_defaults!
      VisitorMultiFactorStatus.ensure_defaults!
      VisitorStatus.ensure_defaults!
      VisitorVisibility.ensure_defaults!
      VisitorEmailStatus.ensure_defaults!
      VisitorTelephoneStatus.ensure_defaults!
      VisitorSecretStatus.ensure_defaults!
      [1, 3, 4].each { |id| VisitorSecretKind.find_or_create_by!(id: id) }
      VisitorPasskeyStatus.ensure_defaults!
    end
  end

  test "visitor tracks verified recovery identity through visitor email and telephone" do
    visitor = Visitor.create!

    assert_not visitor.has_verified_recovery_identity?

    visitor.visitor_emails.create!(
      address: "visitor-#{SecureRandom.hex(4)}@example.com",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      confirm_policy: "1",
    )

    assert_predicate visitor, :verified_email?
    assert_predicate visitor, :has_verified_recovery_identity?

    visitor.visitor_telephones.create!(
      number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
      confirm_policy: "1",
    )

    assert_predicate visitor, :verified_telephone?
  end

  test "visitor secret requires verified recovery identity" do
    visitor = Visitor.create!
    secret = VisitorSecret.new(visitor: visitor, name: "login", password: "a" * 32)

    assert_not secret.valid?
    assert_includes secret.errors[:base], Visitor::RECOVERY_IDENTITY_REQUIRED_MESSAGE
  end

  test "visitor passkey requires verified recovery identity" do
    visitor = Visitor.create!
    passkey = VisitorPasskey.new(
      visitor: visitor,
      webauthn_id: Base64.urlsafe_encode64("visitor_passkey", padding: false),
      external_id: SecureRandom.uuid,
      public_key: "public_key",
      description: "Visitor Passkey",
    )

    assert_not passkey.valid?
    assert_includes passkey.errors[:base], Visitor::RECOVERY_IDENTITY_REQUIRED_MESSAGE
  end
end
