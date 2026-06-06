# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthenticationTokenServiceTest < ActiveSupport::TestCase
  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::ACTIVE)
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorStatus.find_or_create_by!(id: VisitorStatus::RESERVED)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::NOBODY)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::STAFF)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::BOTH)
  end
  test "encode returns nil for nil resource" do
    result = AuthenticationTokenService.encode(nil, host: "example.com", resource_type: "client")

    assert_nil result
  end

  test "encode returns nil for blank host" do
    user = clients(:one)
    result = AuthenticationTokenService.encode(user, host: "", resource_type: "client")

    assert_nil result
  end

  test "decode returns nil for blank token" do
    result = AuthenticationTokenService.decode("", host: "example.com", resource_type: "client")

    assert_nil result
  end

  test "decode returns nil for blank host" do
    result = AuthenticationTokenService.decode("some_token", host: "", resource_type: "client")

    assert_nil result
  end

  test "extract_subject returns subject from payload" do
    payload = { "sub" => 123 }

    assert_equal 123, AuthenticationTokenService.extract_subject(payload)
  end

  test "extract_act returns act from payload" do
    payload = { "act" => "operator" }

    assert_equal "operator", AuthenticationTokenService.extract_act(payload)
  end

  test "extract_session_id returns sid from payload" do
    payload = { "sid" => "abc123" }

    assert_equal "abc123", AuthenticationTokenService.extract_session_id(payload)
  end

  test "extract_jti returns jti from payload" do
    payload = { "jti" => "xyz789" }

    assert_equal "xyz789", AuthenticationTokenService.extract_jti(payload)
  end

  test "validate_actor_claim! returns true for matching user" do
    payload = { "act" => "client" }

    assert AuthenticationTokenService.validate_actor_claim!(payload, "client")
  end

  test "validate_actor_claim! returns false for mismatched actor" do
    payload = { "act" => "client" }

    assert_not AuthenticationTokenService.validate_actor_claim!(payload, "operator")
  end

  test "validate_actor_claim! rejects blank and unknown actor claims" do
    assert_not AuthenticationTokenService.validate_actor_claim!(nil, "client")
    assert_not AuthenticationTokenService.validate_actor_claim!({}, "client")
    assert_not AuthenticationTokenService.validate_actor_claim!({ "act" => "bad" }, "client")
  end

  test "validate_actor_claim! returns true for matching visitor" do
    payload = { "act" => "client" }

    assert AuthenticationTokenService.validate_actor_claim!(payload, "client")
  end

  test "encode creates valid token that can be decoded" do
    user = clients(:one)
    token = AuthenticationTokenService.encode(
      user, host: "example.com", session_id: "sid123",
            resource_type: "client",
    )

    assert_predicate token, :present?

    payload = AuthenticationTokenService.decode(token, host: "example.com", resource_type: "client")

    assert_predicate payload, :present?
    assert_equal user.id, payload["sub"]
  end

  test "encode infers staff resource type" do
    staff = operators(:one)
    token = AuthenticationTokenService.encode(staff, host: "example.com", session_id: "sid-staff")

    assert_predicate token, :present?

    payload = AuthenticationTokenService.decode(token, host: "example.com", resource_type: "operator")

    assert_equal staff.id, payload["sub"]
    assert_equal "operator", payload["act"]
  end

  test "encode returns nil when keyring raises" do
    user = clients(:one)

    JitSecurityJwtKeyring.stub(:encode, ->(*) { raise JWT::EncodeError, "boom" }) do
      assert_nil AuthenticationTokenService.encode(user, host: "example.com", resource_type: "client")
    end
  end

  test "decode rejects token when resource_type issuer/type do not match" do
    user = clients(:one)
    token = AuthenticationTokenService.encode(
      user, host: "example.com", session_id: "sid123",
            resource_type: "client",
    )

    assert_nil AuthenticationTokenService.decode(token, host: "example.com", resource_type: "operator")
  end

  test "encode creates valid visitor token that can be decoded" do
    ensure_visitor_reference_records!
    visitor = Visitor.create!
    token = AuthenticationTokenService.encode(
      visitor, host: "example.com", session_id: "sid999",
               resource_type: "visitor",
    )

    assert_predicate token, :present?

    payload = AuthenticationTokenService.decode(token, host: "example.com", resource_type: "visitor")

    assert_predicate payload, :present?
    assert_equal visitor.id, payload["sub"]
    assert_equal "visitor", payload["act"]
  end

  test "encode infers visitor resource type" do
    ensure_visitor_reference_records!
    visitor = Visitor.create!
    token = AuthenticationTokenService.encode(visitor, host: "example.com", session_id: "sid-visitor")

    assert_predicate token, :present?

    payload = AuthenticationTokenService.decode(token, host: "example.com", resource_type: "visitor")

    assert_equal visitor.id, payload["sub"]
    assert_equal "visitor", payload["act"]
  end

  test "encode includes cnf.jkt when dpop_jkt provided" do
    user = clients(:one)
    token = AuthenticationTokenService.encode(
      user, host: "example.com", session_id: "sid123",
            resource_type: "client", dpop_jkt: "thumb123",
    )

    payload = AuthenticationTokenService.decode(token, host: "example.com", resource_type: "client")

    assert_equal({ "jkt" => "thumb123" }, payload["cnf"])
  end

  test "extract type scopes and scope membership" do
    payload = { "act" => "client", "scp" => "profile email" }

    assert_equal "client", AuthenticationTokenService.extract_type(payload)
    assert_equal "profile email", AuthenticationTokenService.extract_scopes(payload)
    assert AuthenticationTokenService.has_scope?(payload, :profile)
    assert_not AuthenticationTokenService.has_scope?(payload, :admin)
  end

  test "encode backward compatible with session_public_id parameter" do
    user = clients(:one)
    token = AuthenticationTokenService.encode(
      user, host: "example.com", session_public_id: "legacy_sid",
            resource_type: "client",
    )

    payload = AuthenticationTokenService.decode(token, host: "example.com", resource_type: "client")

    assert_equal "legacy_sid", payload["sid"]
  end

  test "encode uses oidc identifiers when provided" do
    user = clients(:one)
    oidc_sid = "5b0d9bbf-963a-4e30-bc1c-a255ca44585a"
    oidc_jti = "6d0d34c8-f250-4480-92ef-154bcbfc9ec7"
    token = AuthenticationTokenService.encode(
      user, host: "example.com", session_public_id: "token_public_id",
            oidc_sid: oidc_sid, oidc_jti: oidc_jti, resource_type: "client",
    )

    payload = AuthenticationTokenService.decode(token, host: "example.com", resource_type: "client")

    assert_equal oidc_sid, payload["sid"]
    assert_equal oidc_jti, payload["jti"]
  end
end
