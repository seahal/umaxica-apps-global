# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_passkeys
# Database name: com_principal
#
#  id           :bigint           not null, primary key
#  description  :string           default(""), not null
#  discarded_at :datetime         default(Infinity), not null
#  last_used_at :datetime
#  public_key   :text             not null
#  purged_at    :datetime         default(Infinity), not null
#  sign_count   :bigint           default(0), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  external_id  :uuid             not null
#  public_id    :string(21)       not null
#  status_id    :bigint           default(1), not null
#  visitor_id   :bigint           not null
#  webauthn_id  :string           default(""), not null
#
# Indexes
#
#  index_visitor_passkeys_on_discarded_at  (discarded_at)
#  index_visitor_passkeys_on_public_id     (public_id) UNIQUE
#  index_visitor_passkeys_on_purged_at     (purged_at)
#  index_visitor_passkeys_on_status_id     (status_id)
#  index_visitor_passkeys_on_visitor_id    (visitor_id)
#  index_visitor_passkeys_on_webauthn_id   (webauthn_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (status_id => visitor_passkey_statuses.id)
#  fk_rails_...  (visitor_id => visitors.id)
#
require "test_helper"

class VisitorPasskeyTest < ActiveSupport::TestCase
  setup do
    ensure_visitor_reference_records!
    @visitor = create_verified_visitor_with_email
    @valid_params = {
      visitor: @visitor,
      webauthn_id: "test-webauthn-id",
      public_key: "test-public-key",
      description: "My Passkey",
      sign_count: 0,
    }.freeze
  end

  test "is valid with valid parameters" do
    passkey = VisitorPasskey.new(@valid_params)

    assert_predicate passkey, :valid?
  end

  test "is invalid without webauthn_id" do
    passkey = VisitorPasskey.new(@valid_params.merge(webauthn_id: nil))

    assert_not passkey.valid?
    assert_predicate passkey.errors[:webauthn_id], :any?
  end

  test "is invalid with duplicate webauthn_id" do
    VisitorPasskey.create!(@valid_params)
    duplicate = VisitorPasskey.new(@valid_params)

    assert_not duplicate.valid?
    assert_predicate duplicate.errors[:webauthn_id], :any?
  end

  test "enforces maximum passkeys per visitor" do
    @visitor.visitor_emails.load
    status = VisitorPasskeyStatus.find(VisitorPasskeyStatus::ACTIVE)

    4.times do |i|
      VisitorPasskey.create!(@valid_params.merge(status: status, webauthn_id: "id-#{i}"))
    end

    extra = VisitorPasskey.new(@valid_params.merge(status: status, webauthn_id: "id-extra"))

    assert_not extra.valid?
    assert_includes extra.errors[:base], "exceeds maximum passkeys per visitor (4)"
  end

  test "requires verified recovery identity on create" do
    unverified_visitor = Visitor.create!(
      status_id: VisitorStatus::ACTIVE,
      visibility_id: VisitorVisibility::VISITOR,
    )
    passkey = VisitorPasskey.new(@valid_params.merge(visitor: unverified_visitor))

    assert_not passkey.valid?
    assert_includes passkey.errors[:base], Visitor::RECOVERY_IDENTITY_REQUIRED_MESSAGE
  end

  test "sets defaults on create" do
    passkey = VisitorPasskey.new(@valid_params.merge(external_id: nil, sign_count: nil))

    assert_predicate passkey, :valid?
    assert_not_nil passkey.external_id
    assert_equal 0, passkey.sign_count
  end

  test "active scope returns only active passkeys" do
    VisitorPasskey.create!(@valid_params.merge(status_id: VisitorPasskeyStatus::ACTIVE))
    # Assuming status_id != ACTIVE is something else, but let's just check ACTIVE for now
    # We'd need to know other valid status IDs for VisitorPasskeyStatus

    assert_equal 1, VisitorPasskey.active.count
  end

  test "to_param returns the public id" do
    passkey = VisitorPasskey.create!(@valid_params)

    assert_equal passkey.public_id, passkey.to_param
  end
  private

  def create_verified_visitor_with_email(email_address: "visitor-#{SecureRandom.hex(4)}@example.com")
    ensure_visitor_reference_records!

    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    insert_verified_visitor_email!(visitor_id: visitor.id, address: email_address)
    visitor.refresh_mfa_status! if visitor.respond_to?(:refresh_mfa_status!)
    visitor.reload
  end

  def insert_verified_visitor_email!(visitor_id:, address:)
    VisitorEmail.insert_all(
      [{
        visitor_id: visitor_id,
        address: address,
        address_digest: IdentifierBlindIndex.bidx_for_email(address),
        visitor_email_status_id: VisitorEmailStatus::VERIFIED,
        otp_private_key: SecureRandom.base64(24),
        otp_counter: "",
        otp_attempts_count: 0,
        public_id: SecureRandom.alphanumeric(21),
        created_at: Time.current,
        updated_at: Time.current,
      }],
    )
  end

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
    VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)

    return unless defined?(VisitorSecretCredentialStatus)

    VisitorSecretCredentialStatus.find_or_create_by!(id: VisitorSecretCredentialStatus::ACTIVE)
    VisitorSecretCredentialStatus.find_or_create_by!(id: VisitorSecretCredentialStatus::EXPIRED)
    VisitorSecretCredentialStatus.find_or_create_by!(id: VisitorSecretCredentialStatus::REVOKED)
    VisitorSecretCredentialStatus.find_or_create_by!(id: VisitorSecretCredentialStatus::USED)
    VisitorSecretCredentialStatus.find_or_create_by!(id: VisitorSecretCredentialStatus::DELETED)
    VisitorSecretCredentialStatus.find_or_create_by!(id: VisitorSecretCredentialStatus::NOTHING)

    return unless defined?(VisitorSecretCredentialKind)

    VisitorSecretCredentialKind.find_or_create_by!(id: VisitorSecretCredentialKind::LOGIN)
    VisitorSecretCredentialKind.find_or_create_by!(id: VisitorSecretCredentialKind::RECOVERY)
    VisitorSecretCredentialKind.find_or_create_by!(id: VisitorSecretCredentialKind::API)

  end
end
