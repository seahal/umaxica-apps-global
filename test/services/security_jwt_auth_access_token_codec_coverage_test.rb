# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SecurityJwtAuthAccessTokenCodecCoverageTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "encode rejects blank inputs and accepts a stubbed success path" do
    assert_nil SecurityJwtAuthAccessTokenCodec.encode(nil, host: "app.example.test")
    assert_nil SecurityJwtAuthAccessTokenCodec.encode(Client.new, host: "")

    payload = { "sub" => "123", "act" => "client" }

    AuthorizationTokenClaims.stub(:build, payload) do
      JitSecurityJwtKeyring.stub(:encode, "encoded.jwt") do
        result =
          SecurityJwtAuthAccessTokenCodec.encode(
            Client.new(id: 123),
            host: "app.example.test",
            resource_type: "client",
            session_public_id: "session-public-id",
          )

        assert_equal "encoded.jwt", result
      end
    end
  end

  test "decode_allow_expired returns nil for bad header and success for a stubbed payload" do
    assert_nil SecurityJwtAuthAccessTokenCodec.decode_allow_expired(nil, host: "app.example.test")
    assert_nil SecurityJwtAuthAccessTokenCodec.decode_allow_expired("token", host: nil)

    header = { "kid" => "kid-1" }
    payload = { "sub" => "123", "act" => "client" }

    JitSecurityJwtKeyring.stub(:parse_header, header) do
      JitSecurityJwtKeyring.stub(:public_key_for, "public-key") do
        JWT.stub(:decode, [payload, header]) do
          SecurityJwtAuthAccessTokenCodec.stub(:valid_header?, true) do
            SecurityJwtAuthAccessTokenCodec.stub(:valid_payload_type?, true) do
              result =
                SecurityJwtAuthAccessTokenCodec.decode_allow_expired(
                  "token",
                  host: "app.example.test",
                  resource_type: "client",
                  issuer: "issuer",
                  audiences: ["aud"],
                )

              assert_equal payload, result
            end
          end
        end
      end
    end
  end

  test "decode_allow_expired returns nil when kid lookup fails" do
    header = { "kid" => "kid-missing" }

    JitSecurityJwtKeyring.stub(:parse_header, header) do
      JitSecurityJwtKeyring.stub(:public_key_for, nil) do
        SecurityJwtAuthAccessTokenCodec.stub(:valid_header?, true) do
          assert_nil(
            SecurityJwtAuthAccessTokenCodec.decode_allow_expired(
              "token",
              host: "app.example.test",
              resource_type: "client",
            ),
          )
        end
      end
    end
  end

  test "decode reports a payload actor mismatch" do
    header = { "kid" => "kid-1" }
    payload = { "sub" => "123", "act" => "operator" }

    JitSecurityJwtKeyring.stub(:parse_header, header) do
      JitSecurityJwtKeyring.stub(:public_key_for, "public-key") do
        JWT.stub(:decode, [payload, header]) do
          SecurityJwtAuthAccessTokenCodec.stub(:valid_header?, true) do
            assert_nil SecurityJwtAuthAccessTokenCodec.decode_allow_expired(
              "token", host: "app.example.test", resource_type: "client",
            )
          end
        end
      end
    end
  end

  test "validate_actor_claim! accepts valid actors and rejects invalid ones" do
    assert_not SecurityJwtAuthAccessTokenCodec.validate_actor_claim!(nil, "client")
    assert_not SecurityJwtAuthAccessTokenCodec.validate_actor_claim!({}, "client")
    assert_not SecurityJwtAuthAccessTokenCodec.validate_actor_claim!({ "act" => "invalid" }, "client")
    assert SecurityJwtAuthAccessTokenCodec.validate_actor_claim!({ "act" => "client" }, "client")
  end

  test "claim extraction helpers delegate to authorization claims" do
    payload = {
      "sub" => "subject-1",
      "act" => "client",
      "sid" => "session-1",
      "jti" => "token-1",
      "scp" => %w(openid profile),
    }

    assert_equal "subject-1", SecurityJwtAuthAccessTokenCodec.extract_subject(payload)
    assert_equal "client", SecurityJwtAuthAccessTokenCodec.extract_type(payload)
    assert_equal "session-1", SecurityJwtAuthAccessTokenCodec.extract_session_id(payload)
    assert_equal "token-1", SecurityJwtAuthAccessTokenCodec.extract_jti(payload)
    assert_equal %w(openid profile), SecurityJwtAuthAccessTokenCodec.extract_scopes(payload)
    assert SecurityJwtAuthAccessTokenCodec.has_scope?(payload, :profile)
    assert_not SecurityJwtAuthAccessTokenCodec.has_scope?(payload, :email)
  end

  test "issuer inference distinguishes service and surface hosts" do
    infer =
      ->(host, type = "client") {
        SecurityJwtAuthAccessTokenCodec.send(
          :inferred_surface_jwt_issuer_id, host: host, resource_type: type,
        )
      }

    assert_equal "surface:ACME_ORG", infer.call("acme.umaxica.org")
    assert_equal "surface:CORE_COM", infer.call("core.umaxica.com")
    assert_equal "surface:ACME_APP", infer.call("acme.app.localhost")
  end

  test "decode options require and verify nbf" do
    options = SecurityJwtAuthAccessTokenCodec.send(
      :decode_options,
      "client",
      "issuer",
      ["audience"],
      verify_exp: true,
    )

    assert_includes options.fetch(:required_claims), "nbf"
    assert options.fetch(:verify_nbf)
  end

  test "decode options require iat" do
    options = SecurityJwtAuthAccessTokenCodec.send(
      :decode_options,
      "client",
      "issuer",
      ["audience"],
      verify_exp: true,
    )

    assert_includes options.fetch(:required_claims), "iat"
  end

  test "rejects a correctly signed token when iat is missing" do
    private_key = OpenSSL::PKey::EC.generate("secp384r1")
    payload = {
      "iss" => "issuer",
      "aud" => "audience",
      "typ" => "access-token+jwt",
      "exp" => 2.minutes.from_now.to_i,
      "nbf" => Time.current.to_i,
      "sub" => "subject",
      "sid" => "session",
      "act" => "client",
      "jti" => "jti",
      "acr" => "aal1",
    }
    token = JWT.encode(payload, private_key, "ES384", { "typ" => "access-token+jwt", "kid" => "kid" })

    JitSecurityJwtKeyring.stub(:public_key_for, private_key.public_key) do
      assert_nil SecurityJwtAuthAccessTokenCodec.decode(
        token,
        host: "app.example.test",
        resource_type: "client",
        issuer: "issuer",
        audiences: ["audience"],
      )
    end
  end

  test "rejects a case-variant algorithm before JWT verification" do
    assert_not SecurityJwtAuthAccessTokenCodec.send(
      :valid_header?,
      { "alg" => "eS384", "typ" => "access-token+jwt", "kid" => "kid" },
      "client",
    )
  end

  test "rejects an unsigned algorithm before JWT verification" do
    assert_not SecurityJwtAuthAccessTokenCodec.send(
      :valid_header?,
      { "alg" => "none", "typ" => "access-token+jwt", "kid" => "kid" },
      "client",
    )
  end
end
