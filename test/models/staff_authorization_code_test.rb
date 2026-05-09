# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_authorization_codes
# Database name: token
#
#  id                    :bigint           not null, primary key
#  acr                   :string
#  auth_method           :string
#  code                  :string(64)       not null
#  code_challenge        :string           not null
#  code_challenge_method :string(8)        default("S256"), not null
#  consumed_at           :datetime
#  lapses_at             :datetime         default(Infinity), not null
#  nonce                 :string
#  purge_at              :datetime         default(Infinity), not null
#  redirect_uri          :text             not null
#  scope                 :string
#  state                 :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  client_id             :string(64)       not null
#  staff_id              :bigint           not null
#
# Indexes
#
#  index_staff_authorization_codes_on_code      (code) UNIQUE
#  index_staff_authorization_codes_on_staff_id  (staff_id)
#
require "test_helper"

class StaffAuthorizationCodeTest < ActiveSupport::TestCase
  setup do
    @staff = Staff.create!(status_id: StaffStatus::ACTIVE)
    @valid_params = {
      client_id: "test-client",
      redirect_uri: "https://example.com/callback",
      code_challenge: "test-challenge",
      code_challenge_method: "S256",
      staff: @staff,
    }.freeze
  end

  test "issue! generates code and sets expires_at" do
    code = StaffAuthorizationCode.issue!(**@valid_params)

    assert_predicate code, :persisted?
    assert_predicate code.code, :present?
    assert_predicate code.lapses_at, :present?
    assert_equal "staff", code.resource_type
    assert_equal @staff, code.resource
  end

  test "validates required fields" do
    code = StaffAuthorizationCode.new(lapses_at: nil)

    assert_not code.valid?
    assert_predicate code.errors[:code], :any?
    assert_predicate code.errors[:client_id], :any?
    assert_predicate code.errors[:redirect_uri], :any?
    assert_predicate code.errors[:code_challenge], :any?
    assert_predicate code.errors[:lapses_at], :any?
  end

  test "validates code_challenge_method inclusion" do
    code = StaffAuthorizationCode.new(
      @valid_params.merge(
        code: "abc", lapses_at: Time.current,
        code_challenge_method: "PLAIN",
      ),
    )

    assert_not code.valid?
    assert_predicate code.errors[:code_challenge_method], :any?
  end

  test "usable? checks expiration, consumption and revocation" do
    code = StaffAuthorizationCode.issue!(**@valid_params)

    assert_predicate code, :usable?

    code.update_columns(lapses_at: 1.minute.ago)

    assert_not_predicate code, :usable?
    assert_predicate code, :expired?

    code.update!(lapses_at: 1.minute.from_now, consumed_at: Time.current)

    assert_not_predicate code, :usable?
    assert_predicate code, :consumed?

    code.update!(consumed_at: nil, lapses_at: Time.current)

    assert_not_predicate code, :usable?
    assert_predicate code, :revoked?
  end

  test "consume! marks as consumed" do
    code = StaffAuthorizationCode.issue!(**@valid_params)
    code.consume!

    assert_predicate code, :consumed?
    assert_raises(RuntimeError) { code.consume! }
  end

  test "revoke! marks as revoked" do
    code = StaffAuthorizationCode.issue!(**@valid_params)
    code.revoke!

    assert_predicate code, :revoked?
    assert_raises(RuntimeError) { code.consume! }
  end

  test "valid scope returns only usable codes" do
    valid = StaffAuthorizationCode.issue!(**@valid_params)
    expired = StaffAuthorizationCode.issue!(**@valid_params)
    expired.update_columns(lapses_at: 1.minute.ago)

    consumed = StaffAuthorizationCode.issue!(**@valid_params)
    consumed.consume!

    revoked = StaffAuthorizationCode.issue!(**@valid_params)
    revoked.revoke!

    valid_codes = StaffAuthorizationCode.valid.to_a

    assert_includes valid_codes, valid
    assert_not_includes valid_codes, expired
    assert_not_includes valid_codes, consumed
    assert_not_includes valid_codes, revoked
  end

  test "verify_pkce" do
    verifier = "test-verifier-123"
    challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)

    code = StaffAuthorizationCode.issue!(**@valid_params.merge(code_challenge: challenge))

    assert code.verify_pkce(verifier)
    assert_not code.verify_pkce("wrong-verifier")
    assert_not code.verify_pkce(nil)
  end
end
