# typed: false
# frozen_string_literal: true

require "test_helper"

module Auth
  class BaseTokenTest < ActiveSupport::TestCase
    test "Token.encode returns nil for nil resource" do
      result = Authentication::Base::Token.encode(nil, host: "example.com")

      assert_nil result
    end

    test "Token.encode returns nil for blank host" do
      user = users(:one)
      result = Authentication::Base::Token.encode(user, host: "")

      assert_nil result
    end

    test "Token.decode returns nil for blank token" do
      result = Authentication::Base::Token.decode("", host: "example.com", resource_type: "user")

      assert_nil result
    end

    test "Token.decode returns nil for blank host" do
      result = Authentication::Base::Token.decode("some_token", host: "", resource_type: "user")

      assert_nil result
    end

    test "Token.extract_subject returns subject from payload" do
      payload = { "sub" => 123 }

      assert_equal 123, Authentication::Base::Token.extract_subject(payload)
    end

    test "Token.extract_type returns act from payload (backward compat alias)" do
      payload = { "act" => "user" }

      assert_equal "user", Authentication::Base::Token.extract_type(payload)
    end

    test "Token.extract_act returns act from payload" do
      payload = { "act" => "operator" }

      assert_equal "operator", Authentication::Base::Token.extract_act(payload)
    end

    test "Token.extract_act returns nil for nil payload" do
      assert_nil Authentication::Base::Token.extract_act(nil)
    end

    test "Token.extract_act returns nil for missing claim" do
      payload = { "sub" => "123" }

      assert_nil Authentication::Base::Token.extract_act(payload)
    end

    test "Token.validate_actor_claim! returns true for matching user" do
      payload = { "act" => "user" }

      assert Authentication::Base::Token.validate_actor_claim!(payload, "user")
    end

    test "Token.validate_actor_claim! returns true for matching operator" do
      payload = { "act" => "operator" }

      assert Authentication::Base::Token.validate_actor_claim!(payload, "operator")
    end

    test "Token.validate_actor_claim! returns false for mismatched actor" do
      payload = { "act" => "user" }

      assert_not Authentication::Base::Token.validate_actor_claim!(payload, "operator")
    end

    test "Token.validate_actor_claim! returns false for nil payload" do
      assert_not Authentication::Base::Token.validate_actor_claim!(nil, "user")
    end

    test "Token.validate_actor_claim! returns false for missing claim" do
      payload = { "sub" => "123" }

      assert_not Authentication::Base::Token.validate_actor_claim!(payload, "user")
    end

    test "Token.validate_actor_claim! returns false for blank claim" do
      payload = { "act" => "" }

      assert_not Authentication::Base::Token.validate_actor_claim!(payload, "user")
    end

    test "Token.validate_actor_claim! returns false for unrecognized value" do
      payload = { "act" => "staff" }

      assert_not Authentication::Base::Token.validate_actor_claim!(payload, "operator")
    end

    test "Token.validate_actor_claim! returns false for nil value" do
      payload = { "act" => nil }

      assert_not Authentication::Base::Token.validate_actor_claim!(payload, "user")
    end

    test "Token.extract_session_id returns sid from payload" do
      payload = { "sid" => "abc123" }

      assert_equal "abc123", Authentication::Base::Token.extract_session_id(payload)
    end

    test "Token.extract_jti returns jti from payload" do
      payload = { "jti" => "xyz789" }

      assert_equal "xyz789", Authentication::Base::Token.extract_jti(payload)
    end

    test "Token.encode includes kid header" do
      token = Authentication::Base::Token.encode(
        users(:one), host: "example.com", session_public_id: "sid", resource_type: "user",
      )
      _payload, header = JWT.decode(token, nil, false)

      assert_predicate header["kid"], :present?
      assert_equal "auth-access-token;user", header["typ"]
    end

    test "Token.decode rejects unknown kid" do
      token = Authentication::Base::Token.encode(
        users(:one), host: "example.com", session_public_id: "sid", resource_type: "user",
      )
      payload, header = JWT.decode(token, nil, false)
      tampered = JWT.encode(
        payload, Authentication::Base::JwtConfiguration.private_key, "ES384",
        { kid: "unknown-kid", typ: header["typ"] },
      )

      assert_nil Authentication::Base::Token.decode(tampered, host: "example.com", resource_type: "user")
    end

    test "Token.decode rejects alg mismatch" do
      token = Authentication::Base::Token.encode(
        users(:one), host: "example.com", session_public_id: "sid", resource_type: "user",
      )
      payload, _header = JWT.decode(token, nil, false)
      active_kid = Jit::Security::Jwt::Keyring.active_kid
      tampered = JWT.encode(payload, "secret", "HS256", { kid: active_kid, typ: "auth-access-token;user" })

      assert_nil Authentication::Base::Token.decode(tampered, host: "example.com", resource_type: "user")
    end

    test "Token.decode rejects alg none" do
      token = Authentication::Base::Token.encode(
        users(:one), host: "example.com", session_public_id: "sid", resource_type: "user",
      )
      payload, _header = JWT.decode(token, nil, false)
      tampered = JWT.encode(
        payload,
        nil,
        "none",
        { kid: Jit::Security::Jwt::Keyring.active_kid, typ: "auth-access-token;user" },
      )

      assert_nil Authentication::Base::Token.decode(tampered, host: "example.com", resource_type: "user")
    end

    test "Token.decode rejects missing sid claim" do
      token = Authentication::Base::Token.encode(
        users(:one), host: "example.com", session_public_id: "sid", resource_type: "user",
      )
      payload, header = JWT.decode(token, nil, false)
      payload.delete("sid")
      tampered = JWT.encode(payload, Authentication::Base::JwtConfiguration.private_key, "ES384", header)

      assert_nil Authentication::Base::Token.decode(tampered, host: "example.com", resource_type: "user")
    end

    test "Token.decode rejects missing sub claim" do
      token = Authentication::Base::Token.encode(
        users(:one), host: "example.com", session_public_id: "sid", resource_type: "user",
      )
      payload, header = JWT.decode(token, nil, false)
      payload.delete("sub")
      tampered = JWT.encode(payload, Authentication::Base::JwtConfiguration.private_key, "ES384", header)

      assert_nil Authentication::Base::Token.decode(tampered, host: "example.com", resource_type: "user")
    end

    test "Token.decode rejects missing typ claim" do
      token = Authentication::Base::Token.encode(
        users(:one), host: "example.com", session_public_id: "sid", resource_type: "user",
      )
      payload, header = JWT.decode(token, nil, false)
      payload.delete("typ")
      tampered = JWT.encode(payload, Authentication::Base::JwtConfiguration.private_key, "ES384", header)

      assert_nil Authentication::Base::Token.decode(tampered, host: "example.com", resource_type: "user")
    end

    test "Token.decode rejects user token for operator resource type" do
      token = Authentication::Base::Token.encode(
        users(:one), host: "example.com", session_public_id: "sid", resource_type: "user",
      )

      assert_nil Authentication::Base::Token.decode(token, host: "example.com", resource_type: "operator")
    end
  end
end
