# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Auth
  class BaseTokenTest < ActiveSupport::TestCase
    test "Token.encode returns nil for nil resource" do
      result = AuthenticationToken.encode(nil, host: "example.com")

      assert_nil result
    end

    test "Token.encode returns nil for blank host" do
      user = clients(:one)
      result = AuthenticationToken.encode(user, host: "")

      assert_nil result
    end

    test "Token.decode returns nil for blank token" do
      result = AuthenticationToken.decode("", host: "example.com", resource_type: "client")

      assert_nil result
    end

    test "Token.decode returns nil for blank host" do
      result = AuthenticationToken.decode("some_token", host: "", resource_type: "client")

      assert_nil result
    end

    test "Token.extract_subject returns subject from payload" do
      payload = { "sub" => 123 }

      assert_equal 123, AuthenticationToken.extract_subject(payload)
    end

    test "Token.extract_type returns act from payload (backward compat alias)" do
      payload = { "act" => "client" }

      assert_equal "client", AuthenticationToken.extract_type(payload)
    end

    test "Token.extract_act returns act from payload" do
      payload = { "act" => "operator" }

      assert_equal "operator", AuthenticationToken.extract_act(payload)
    end

    test "Token.extract_act returns nil for nil payload" do
      assert_nil AuthenticationToken.extract_act(nil)
    end

    test "Token.extract_act returns nil for missing claim" do
      payload = { "sub" => "123" }

      assert_nil AuthenticationToken.extract_act(payload)
    end

    test "Token.validate_actor_claim! returns true for matching user" do
      payload = { "act" => "client" }

      assert AuthenticationToken.validate_actor_claim!(payload, "client")
    end

    test "Token.validate_actor_claim! returns true for matching operator" do
      payload = { "act" => "operator" }

      assert AuthenticationToken.validate_actor_claim!(payload, "operator")
    end

    test "Token.validate_actor_claim! returns false for mismatched actor" do
      payload = { "act" => "client" }

      assert_not AuthenticationToken.validate_actor_claim!(payload, "operator")
    end

    test "Token.validate_actor_claim! returns false for nil payload" do
      assert_not AuthenticationToken.validate_actor_claim!(nil, "client")
    end

    test "Token.validate_actor_claim! returns false for missing claim" do
      payload = { "sub" => "123" }

      assert_not AuthenticationToken.validate_actor_claim!(payload, "client")
    end

    test "Token.validate_actor_claim! returns false for blank claim" do
      payload = { "act" => "" }

      assert_not AuthenticationToken.validate_actor_claim!(payload, "client")
    end

    test "Token.validate_actor_claim! returns false for unrecognized value" do
      payload = { "act" => "staff" }

      assert_not AuthenticationToken.validate_actor_claim!(payload, "operator")
    end

    test "Token.validate_actor_claim! returns false for nil value" do
      payload = { "act" => nil }

      assert_not AuthenticationToken.validate_actor_claim!(payload, "client")
    end

    test "Token.extract_session_id returns sid from payload" do
      payload = { "sid" => "abc123" }

      assert_equal "abc123", AuthenticationToken.extract_session_id(payload)
    end

    test "Token.extract_jti returns jti from payload" do
      payload = { "jti" => "xyz789" }

      assert_equal "xyz789", AuthenticationToken.extract_jti(payload)
    end

    test "Token.encode includes kid header" do
      token = AuthenticationToken.encode(
        clients(:one), host: "example.com", session_public_id: "sid", resource_type: "client",
      )
      _payload, header = JWT.decode(token, nil, false)

      assert_predicate header["kid"], :present?
      assert_equal "auth-access-token;client", header["typ"]
    end

    test "Token roundtrips with an explicit surface issuer and not the legacy auth issuer" do
      token = AuthenticationToken.encode(
        clients(:one),
        host: "log.umaxica.app",
        session_public_id: "sid",
        resource_type: "client",
        jwt_issuer_id: "surface:SIGN_APP",
      )

      assert AuthenticationToken.decode(token, host: "log.umaxica.app", resource_type: "client")

      payload = AuthenticationToken.decode(
        token,
        host: "log.umaxica.app",
        resource_type: "client",
        jwt_issuer_id: "surface:SIGN_APP",
      )

      assert_equal clients(:one).id, payload["sub"]
    end

    test "Token.decode rejects unknown kid" do
      token = AuthenticationToken.encode(
        clients(:one), host: "example.com", session_public_id: "sid", resource_type: "client",
      )
      payload, header = JWT.decode(token, nil, false)
      tampered = JWT.encode(
        payload, AuthenticationJwtConfiguration.private_key, "ES384",
        { kid: "unknown-kid", typ: header["typ"] },
      )

      assert_nil AuthenticationToken.decode(tampered, host: "example.com", resource_type: "client")
    end

    test "Token.decode rejects alg mismatch" do
      token = AuthenticationToken.encode(
        clients(:one), host: "example.com", session_public_id: "sid", resource_type: "client",
      )
      payload, _header = JWT.decode(token, nil, false)
      active_kid = JitSecurityJwtKeyring.active_kid
      tampered = JWT.encode(payload, "secret_credential", "HS256", { kid: active_kid, typ: "auth-access-token;client" })

      assert_nil AuthenticationToken.decode(tampered, host: "example.com", resource_type: "client")
    end

    test "Token.decode rejects alg none" do
      token = AuthenticationToken.encode(
        clients(:one), host: "example.com", session_public_id: "sid", resource_type: "client",
      )
      payload, _header = JWT.decode(token, nil, false)
      tampered = JWT.encode(
        payload,
        nil,
        "none",
        { kid: JitSecurityJwtKeyring.active_kid, typ: "auth-access-token;client" },
      )

      assert_nil AuthenticationToken.decode(tampered, host: "example.com", resource_type: "client")
    end

    test "Token.decode rejects missing sid claim" do
      token = AuthenticationToken.encode(
        clients(:one), host: "example.com", session_public_id: "sid", resource_type: "client",
      )
      payload, header = JWT.decode(token, nil, false)
      payload.delete("sid")
      tampered = JWT.encode(payload, AuthenticationJwtConfiguration.private_key, "ES384", header)

      assert_nil AuthenticationToken.decode(tampered, host: "example.com", resource_type: "client")
    end

    test "Token.decode rejects missing sub claim" do
      token = AuthenticationToken.encode(
        clients(:one), host: "example.com", session_public_id: "sid", resource_type: "client",
      )
      payload, header = JWT.decode(token, nil, false)
      payload.delete("sub")
      tampered = JWT.encode(payload, AuthenticationJwtConfiguration.private_key, "ES384", header)

      assert_nil AuthenticationToken.decode(tampered, host: "example.com", resource_type: "client")
    end

    test "Token.decode rejects missing typ claim" do
      token = AuthenticationToken.encode(
        clients(:one), host: "example.com", session_public_id: "sid", resource_type: "client",
      )
      payload, header = JWT.decode(token, nil, false)
      payload.delete("typ")
      tampered = JWT.encode(payload, AuthenticationJwtConfiguration.private_key, "ES384", header)

      assert_nil AuthenticationToken.decode(tampered, host: "example.com", resource_type: "client")
    end

    test "Token.decode rejects user token for operator resource type" do
      token = AuthenticationToken.encode(
        clients(:one), host: "example.com", session_public_id: "sid", resource_type: "client",
      )

      assert_nil AuthenticationToken.decode(token, host: "example.com", resource_type: "operator")
    end
  end
end
