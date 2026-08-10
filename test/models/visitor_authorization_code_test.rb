# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_authorization_codes
# Database name: com_ticket
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
#  visitor_id            :bigint           not null
#
# Indexes
#
#  index_visitor_authorization_codes_on_code        (code) UNIQUE
#  index_visitor_authorization_codes_on_visitor_id  (visitor_id)
#
require "test_helper"

class VisitorAuthorizationCodeTest < ActiveSupport::TestCase
  setup do
    VisitorStatus.ensure_defaults!
    VisitorVisibility.ensure_defaults!
    @visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    @visitor_session_token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    @valid_params = {
      client_id: "test-client",
      redirect_uri: "https://example.com/callback",
      code_challenge: "test-challenge",
      code_challenge_method: "S256",
      visitor: @visitor,
      visitor_token: @visitor_session_token,
    }.freeze
  end

  test "issue! generates code and sets expiry" do
    code = VisitorAuthorizationCode.issue!(**@valid_params)

    assert_predicate code, :persisted?
    assert_predicate code.code, :present?
    assert_predicate code.discarded_at, :present?
    assert_equal "visitor", code.resource_type
    assert_equal @visitor, code.resource
  end

  test "validates required fields" do
    code = VisitorAuthorizationCode.new(discarded_at: nil)

    assert_not code.valid?
    assert_predicate code.errors[:code], :any?
    assert_predicate code.errors[:client_id], :any?
    assert_predicate code.errors[:redirect_uri], :any?
    assert_predicate code.errors[:code_challenge], :any?
    assert_predicate code.errors[:discarded_at], :any?
  end

  test "validates code challenge method inclusion" do
    code = VisitorAuthorizationCode.new(
      @valid_params.merge(
        code: "abc",
        discarded_at: Time.current,
        code_challenge_method: "PLAIN",
      ),
    )

    assert_not code.valid?
    assert_predicate code.errors[:code_challenge_method], :any?
  end

  test "validates code and client_id length boundaries" do
    code = VisitorAuthorizationCode.new(
      @valid_params.merge(
        code: "x" * 65,
        client_id: "x" * 65,
        code_challenge_method: "S256",
        discarded_at: Time.current,
      ),
    )

    assert_not code.valid?
    assert_predicate code.errors[:code], :any?
    assert_predicate code.errors[:client_id], :any?
  end

  test "validates code_challenge_method length boundary" do
    code = VisitorAuthorizationCode.new(
      @valid_params.merge(
        code: "abc",
        client_id: "test-client",
        discarded_at: Time.current,
        code_challenge_method: "S256S2569",
      ),
    )

    assert_not code.valid?
    assert_predicate code.errors[:code_challenge_method], :any?
  end

  test "usable? checks expiration and consumption" do
    code = VisitorAuthorizationCode.issue!(**@valid_params)

    assert_predicate code, :usable?

    code.update_columns(discarded_at: 1.minute.ago)

    assert_not_predicate code, :usable?
    assert_predicate code, :expired?

    code.update!(discarded_at: 1.minute.from_now, consumed_at: Time.current)

    assert_not_predicate code, :usable?
    assert_predicate code, :consumed?
  end

  test "consume! marks code as consumed and rejects reuse" do
    code = VisitorAuthorizationCode.issue!(**@valid_params)

    code.consume!

    assert_predicate code, :consumed?
    assert_raises(RuntimeError) { code.consume! }
  end

  test "revoke! makes code unusable" do
    code = VisitorAuthorizationCode.issue!(**@valid_params)

    code.revoke!

    assert_predicate code, :revoked?
    assert_raises(RuntimeError) { code.consume! }
  end

  test "valid scope returns only unconsumed unexpired codes" do
    valid = VisitorAuthorizationCode.issue!(**@valid_params)
    expired = VisitorAuthorizationCode.issue!(**@valid_params)
    expired.update_columns(discarded_at: 1.minute.ago)

    consumed = VisitorAuthorizationCode.issue!(**@valid_params)
    consumed.consume!

    revoked = VisitorAuthorizationCode.issue!(**@valid_params)
    revoked.revoke!

    valid_codes = VisitorAuthorizationCode.valid.to_a

    assert_includes valid_codes, valid
    assert_not_includes valid_codes, expired
    assert_not_includes valid_codes, consumed
    assert_not_includes valid_codes, revoked
  end

  test "verify_pkce accepts matching verifier and rejects blank or mismatched verifier" do
    verifier = "a" * 43
    challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
    code = VisitorAuthorizationCode.issue!(**@valid_params.merge(code_challenge: challenge))

    assert code.verify_pkce(verifier)
    assert_not code.verify_pkce("wrong-verifier")
    assert_not code.verify_pkce(nil)
  end

  test "verify_pkce rejects a code_verifier shorter than the RFC 7636 43 character minimum" do
    verifier = "a" * 42
    challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
    code = VisitorAuthorizationCode.issue!(**@valid_params.merge(code_challenge: challenge))

    assert_not code.verify_pkce(verifier), "a 42-character verifier must be rejected even when the SHA256 digest matches"
  end

  test "verify_pkce rejects a code_verifier longer than the RFC 7636 128 character maximum" do
    verifier = "a" * 129
    challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
    code = VisitorAuthorizationCode.issue!(**@valid_params.merge(code_challenge: challenge))

    assert_not code.verify_pkce(verifier), "a 129-character verifier must be rejected even when the SHA256 digest matches"
  end

  test "verify_pkce rejects a code_verifier containing characters outside the RFC 7636 unreserved set" do
    verifier = "#{"a" * 42}*"
    challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
    code = VisitorAuthorizationCode.issue!(**@valid_params.merge(code_challenge: challenge))

    assert_not code.verify_pkce(verifier), "a verifier containing '*' is outside A-Z/a-z/0-9/-._~ and must be rejected"
  end
end
