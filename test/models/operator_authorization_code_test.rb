# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_authorization_codes
# Database name: org_ticket
#
#  id                    :bigint           not null, primary key
#  acr                   :string
#  auth_method           :string
#  code                  :string(64)       not null
#  code_challenge        :string           not null
#  code_challenge_method :string(8)        default("S256"), not null
#  consumed_at           :datetime
#  discarded_at          :datetime         default(Infinity), not null
#  nonce                 :string
#  purged_at             :datetime         default(Infinity), not null
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
#  index_operator_authorization_codes_on_code      (code) UNIQUE
#  index_operator_authorization_codes_on_staff_id  (staff_id)
#
require "test_helper"

class OperatorAuthorizationCodeTest < ActiveSupport::TestCase
  setup do
    @staff = Operator.create!(status_id: OperatorStatus::ACTIVE)
    @valid_params = {
      client_id: "test-client",
      redirect_uri: "https://example.com/callback",
      code_challenge: "test-challenge",
      code_challenge_method: "S256",
      staff: @staff,
    }.freeze
  end

  test "issue! generates code and sets expires_at" do
    code = OperatorAuthorizationCode.issue!(**@valid_params)

    assert_predicate code, :persisted?
    assert_predicate code.code, :present?
    assert_predicate code.discarded_at, :present?
    assert_equal "operator", code.resource_type
    assert_equal @staff.id, code.resource.id
  end

  test "validates required fields" do
    code = OperatorAuthorizationCode.new(discarded_at: nil)

    assert_not code.valid?
    assert_predicate code.errors[:code], :any?
    assert_predicate code.errors[:client_id], :any?
    assert_predicate code.errors[:redirect_uri], :any?
    assert_predicate code.errors[:code_challenge], :any?
    assert_predicate code.errors[:discarded_at], :any?
  end

  test "validates code_challenge_method inclusion" do
    code = OperatorAuthorizationCode.new(
      @valid_params.merge(
        code: "abc", discarded_at: Time.current,
        code_challenge_method: "PLAIN",
      ),
    )

    assert_not code.valid?
    assert_predicate code.errors[:code_challenge_method], :any?
  end

  test "usable? checks expiration, consumption and revocation" do
    code = OperatorAuthorizationCode.issue!(**@valid_params)

    assert_predicate code, :usable?

    code.update_columns(discarded_at: 1.minute.ago)

    assert_not_predicate code, :usable?
    assert_predicate code, :expired?

    code.update!(discarded_at: 1.minute.from_now, consumed_at: Time.current)

    assert_not_predicate code, :usable?
    assert_predicate code, :consumed?

    code.update!(consumed_at: nil, discarded_at: Time.current)

    assert_not_predicate code, :usable?
    assert_predicate code, :revoked?
  end

  test "consume! marks as consumed" do
    code = OperatorAuthorizationCode.issue!(**@valid_params)
    code.consume!

    assert_predicate code, :consumed?
    assert_raises(RuntimeError) { code.consume! }
  end

  test "revoke! marks as revoked" do
    code = OperatorAuthorizationCode.issue!(**@valid_params)
    code.revoke!

    assert_predicate code, :revoked?
    assert_raises(RuntimeError) { code.consume! }
  end

  test "valid scope returns only usable codes" do
    valid = OperatorAuthorizationCode.issue!(**@valid_params)
    expired = OperatorAuthorizationCode.issue!(**@valid_params)
    expired.update_columns(discarded_at: 1.minute.ago)

    consumed = OperatorAuthorizationCode.issue!(**@valid_params)
    consumed.consume!

    revoked = OperatorAuthorizationCode.issue!(**@valid_params)
    revoked.revoke!

    valid_codes = OperatorAuthorizationCode.valid.to_a

    assert_includes valid_codes, valid
    assert_not_includes valid_codes, expired
    assert_not_includes valid_codes, consumed
    assert_not_includes valid_codes, revoked
  end

  test "verify_pkce" do
    verifier = "test-verifier-123"
    challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)

    code = OperatorAuthorizationCode.issue!(**@valid_params.merge(code_challenge: challenge))

    assert code.verify_pkce(verifier)
    assert_not code.verify_pkce("wrong-verifier")
    assert_not code.verify_pkce(nil)
  end
end
