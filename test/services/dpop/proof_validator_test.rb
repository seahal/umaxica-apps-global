# typed: false
# frozen_string_literal: true

require "test_helper"

module Dpop
  class ProofValidatorTest < ActiveSupport::TestCase
    def generate_proof_jwk
      ec = OpenSSL::PKey::EC.generate("prime256v1")
      jwk = JWT::JWK.new(ec)
      [ec, jwk.export]
    end

    def build_proof(private_key, jwk, method:, uri:, iat: Time.current.to_i, ath: nil, jti: SecureRandom.uuid)
      payload = { "htm" => method, "htu" => uri, "iat" => iat, "jti" => jti }
      payload["ath"] = ath if ath.present?
      JWT.encode(payload, private_key, "ES256", { "typ" => "dpop+jwt", "jwk" => jwk })
    end

    test "valid proof returns success" do
      private_key, jwk = generate_proof_jwk
      proof = build_proof(private_key, jwk, method: "GET", uri: "http://example.com/api")

      result = ProofValidator.new(
        proof_jwt: proof,
        request_method: "GET",
        request_uri: "http://example.com/api",
      ).call

      assert_predicate result, :valid?
      assert_nil result.error
      assert_predicate result.jkt, :present?
    end

    test "missing proof returns error" do
      result = ProofValidator.new(
        proof_jwt: nil,
        request_method: "GET",
        request_uri: "http://example.com/api",
      ).call

      assert_not result.valid?
      assert_equal "missing_proof", result.error
    end

    test "malformed proof returns error" do
      result = ProofValidator.new(
        proof_jwt: "not.a.jwt",
        request_method: "GET",
        request_uri: "http://example.com/api",
      ).call

      assert_not result.valid?
      assert_equal "malformed_proof", result.error
    end

    test "invalid typ returns error" do
      private_key, jwk = generate_proof_jwk
      payload = { "htm" => "GET", "htu" => "http://example.com/api", "iat" => Time.current.to_i }
      proof = JWT.encode(payload, private_key, "ES256", { "typ" => "jwt", "jwk" => jwk })

      result = ProofValidator.new(
        proof_jwt: proof,
        request_method: "GET",
        request_uri: "http://example.com/api",
      ).call

      assert_not result.valid?
      assert_equal "invalid_typ", result.error
    end

    test "unsupported alg returns error" do
      rsa = OpenSSL::PKey::RSA.generate(2048)
      jwk = JWT::JWK.new(rsa).export
      payload = { "htm" => "GET", "htu" => "http://example.com/api", "iat" => Time.current.to_i }
      proof = JWT.encode(payload, rsa, "RS256", { "typ" => "dpop+jwt", "jwk" => jwk })

      result = ProofValidator.new(
        proof_jwt: proof,
        request_method: "GET",
        request_uri: "http://example.com/api",
      ).call

      assert_not result.valid?
      assert_equal "unsupported_alg", result.error
    end

    test "missing jwk returns error" do
      private_key, = generate_proof_jwk
      payload = { "htm" => "GET", "htu" => "http://example.com/api", "iat" => Time.current.to_i }
      proof = JWT.encode(payload, private_key, "ES256", { "typ" => "dpop+jwt" })

      result = ProofValidator.new(
        proof_jwt: proof,
        request_method: "GET",
        request_uri: "http://example.com/api",
      ).call

      assert_not result.valid?
      assert_equal "missing_jwk", result.error
    end

    test "private key in jwk returns error" do
      private_key, jwk = generate_proof_jwk
      jwk["d"] = "private"
      payload = { "htm" => "GET", "htu" => "http://example.com/api", "iat" => Time.current.to_i }
      proof = JWT.encode(payload, private_key, "ES256", { "typ" => "dpop+jwt", "jwk" => jwk })

      result = ProofValidator.new(
        proof_jwt: proof,
        request_method: "GET",
        request_uri: "http://example.com/api",
      ).call

      assert_not result.valid?
      assert_equal "private_key_in_jwk", result.error
    end

    test "htm mismatch returns error" do
      private_key, jwk = generate_proof_jwk
      proof = build_proof(private_key, jwk, method: "POST", uri: "http://example.com/api")

      result = ProofValidator.new(
        proof_jwt: proof,
        request_method: "GET",
        request_uri: "http://example.com/api",
      ).call

      assert_not result.valid?
      assert_equal "htm_mismatch", result.error
    end

    test "htu mismatch returns error" do
      private_key, jwk = generate_proof_jwk
      proof = build_proof(private_key, jwk, method: "GET", uri: "http://example.com/other")

      result = ProofValidator.new(
        proof_jwt: proof,
        request_method: "GET",
        request_uri: "http://example.com/api",
      ).call

      assert_not result.valid?
      assert_equal "htu_mismatch", result.error
    end

    test "iat out of window returns error" do
      private_key, jwk = generate_proof_jwk
      proof = build_proof(private_key, jwk, method: "GET", uri: "http://example.com/api", iat: Time.current.to_i - 120)

      result = ProofValidator.new(
        proof_jwt: proof,
        request_method: "GET",
        request_uri: "http://example.com/api",
      ).call

      assert_not result.valid?
      assert_equal "iat_out_of_window", result.error
    end

    test "missing jti does not fail while replay detection is deferred" do
      private_key, jwk = generate_proof_jwk
      payload = { "htm" => "GET", "htu" => "http://example.com/api", "iat" => Time.current.to_i }
      proof = JWT.encode(payload, private_key, "ES256", { "typ" => "dpop+jwt", "jwk" => jwk })

      result = ProofValidator.new(
        proof_jwt: proof,
        request_method: "GET",
        request_uri: "http://example.com/api",
      ).call

      assert_predicate result, :valid?
    end

    test "missing jti fails when replay detection is enabled" do
      private_key, jwk = generate_proof_jwk
      payload = { "htm" => "GET", "htu" => "http://example.com/api", "iat" => Time.current.to_i }
      proof = JWT.encode(payload, private_key, "ES256", { "typ" => "dpop+jwt", "jwk" => jwk })

      with_env("DPOP_JTI_REPLAY_DETECTION_ENABLED" => "true") do
        result = ProofValidator.new(
          proof_jwt: proof,
          request_method: "GET",
          request_uri: "http://example.com/api",
        ).call

        assert_not result.valid?
        assert_equal "missing_jti", result.error
      end
    end

    test "ath mismatch returns error" do
      private_key, jwk = generate_proof_jwk
      proof = build_proof(private_key, jwk, method: "GET", uri: "http://example.com/api", ath: "wrong_ath")

      result = ProofValidator.new(
        proof_jwt: proof,
        request_method: "GET",
        request_uri: "http://example.com/api",
        access_token: "real_access_token",
      ).call

      assert_not result.valid?
      assert_equal "ath_mismatch", result.error
    end

    test "ath match succeeds" do
      private_key, jwk = generate_proof_jwk
      access_token = "real_access_token"
      ath = Jit::Security::Jwt::ThumbprintCalculator.ath(access_token)
      proof = build_proof(private_key, jwk, method: "GET", uri: "http://example.com/api", ath: ath)

      result = ProofValidator.new(
        proof_jwt: proof,
        request_method: "GET",
        request_uri: "http://example.com/api",
        access_token: access_token,
      ).call

      assert_predicate result, :valid?
    end

    test "invalid signature returns error" do
      _, jwk = generate_proof_jwk
      other_key = OpenSSL::PKey::EC.generate("prime256v1")
      payload = { "htm" => "GET", "htu" => "http://example.com/api", "iat" => Time.current.to_i }
      proof = JWT.encode(payload, other_key, "ES256", { "typ" => "dpop+jwt", "jwk" => jwk })

      result = ProofValidator.new(
        proof_jwt: proof,
        request_method: "GET",
        request_uri: "http://example.com/api",
      ).call

      assert_not result.valid?
      assert_equal "invalid_signature", result.error
    end

    def with_env(values)
      previous = values.keys.index_with { |key| ENV[key] }
      values.each { |key, value| ENV[key] = value }
      yield
    ensure
      previous.each do |key, value|
        value.nil? ? ENV.delete(key) : ENV[key] = value
      end
    end
  end
end
