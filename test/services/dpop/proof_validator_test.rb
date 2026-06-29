# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

module Dpop
  class ProofValidatorTest < ActiveSupport::TestCase
    setup do
      ClientDpopProofState.delete_all
    end

    def generate_proof_jwk
      ec = OpenSSL::PKey::EC.generate("prime256v1")
      jwk = JWT::JWK.new(ec)
      [ec, jwk.export]
    end

    def build_proof(private_key, jwk, method:, uri:, iat: Time.current.to_i, ath: nil, jti: SecureRandom.uuid,
                    nonce: nil)
      payload = { "htm" => method, "htu" => uri, "iat" => iat, "jti" => jti }
      payload["ath"] = ath if ath.present?
      payload["nonce"] = nonce if nonce.present?
      JWT.encode(payload, private_key, "ES256", { "typ" => "dpop+jwt", "jwk" => jwk })
    end

    test "valid proof returns success" do
      private_key, jwk = generate_proof_jwk
      proof = build_proof(private_key, jwk, method: "GET", uri: "http://example.com/api")

      result = DpopProofValidator.new(
        proof_jwt: proof,
        request_method: "GET",
        request_uri: "http://example.com/api",
      ).call

      assert_predicate result, :valid?
      assert_nil result.error
      assert_predicate result.jkt, :present?
    end

    test "missing proof returns error" do
      result = DpopProofValidator.new(
        proof_jwt: nil,
        request_method: "GET",
        request_uri: "http://example.com/api",
      ).call

      assert_not result.valid?
      assert_equal "missing_proof", result.error
    end

    test "malformed proof returns error" do
      result = DpopProofValidator.new(
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

      result = DpopProofValidator.new(
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

      result = DpopProofValidator.new(
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

      result = DpopProofValidator.new(
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

      result = DpopProofValidator.new(
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

      result = DpopProofValidator.new(
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

      result = DpopProofValidator.new(
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

      result = DpopProofValidator.new(
        proof_jwt: proof,
        request_method: "GET",
        request_uri: "http://example.com/api",
      ).call

      assert_not result.valid?
      assert_equal "iat_out_of_window", result.error
    end

    test "missing jti fails" do
      private_key, jwk = generate_proof_jwk
      payload = { "htm" => "GET", "htu" => "http://example.com/api", "iat" => Time.current.to_i }
      proof = JWT.encode(payload, private_key, "ES256", { "typ" => "dpop+jwt", "jwk" => jwk })

      result = DpopProofValidator.new(
        proof_jwt: proof,
        request_method: "GET",
        request_uri: "http://example.com/api",
      ).call

      assert_not result.valid?
      assert_equal "missing_jti", result.error
    end

    test "ath mismatch returns error" do
      private_key, jwk = generate_proof_jwk
      proof = build_proof(private_key, jwk, method: "GET", uri: "http://example.com/api", ath: "wrong_ath")

      result = DpopProofValidator.new(
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
      ath = JitSecurityJwtThumbprintCalculator.ath(access_token)
      proof = build_proof(private_key, jwk, method: "GET", uri: "http://example.com/api", ath: ath)

      result = DpopProofValidator.new(
        proof_jwt: proof,
        request_method: "GET",
        request_uri: "http://example.com/api",
        access_token: access_token,
      ).call

      assert_predicate result, :valid?
    end

    test "nonce match succeeds and consumes nonce" do
      private_key, jwk = generate_proof_jwk
      nonce = DpopNonceService.generate
      proof = build_proof(private_key, jwk, method: "GET", uri: "http://example.com/api", nonce: nonce)

      result = DpopProofValidator.new(
        proof_jwt: proof,
        request_method: "GET",
        request_uri: "http://example.com/api",
      ).call

      assert_predicate result, :valid?
      assert_not DpopNonceService.verify(nonce)
    end

    test "unknown nonce fails" do
      private_key, jwk = generate_proof_jwk
      proof = build_proof(private_key, jwk, method: "GET", uri: "http://example.com/api", nonce: "missing")

      result = DpopProofValidator.new(
        proof_jwt: proof,
        request_method: "GET",
        request_uri: "http://example.com/api",
      ).call

      assert_not result.valid?
      assert_equal "nonce_invalid", result.error
    end

    test "record_jti true persists jti and detects replay" do
      private_key, jwk = generate_proof_jwk
      jti = SecureRandom.uuid
      proof = build_proof(private_key, jwk, method: "GET", uri: "http://example.com/api", jti: jti)

      first = DpopProofValidator.new(
        proof_jwt: proof,
        request_method: "GET",
        request_uri: "http://example.com/api",
      ).call

      assert_predicate first, :valid?
      assert_equal 1, ClientDpopProofState.where(jti: jti).count

      replay = DpopProofValidator.new(
        proof_jwt: proof,
        request_method: "GET",
        request_uri: "http://example.com/api",
      ).call

      assert_not replay.valid?
      assert_equal "jti_replay", replay.error
    end

    test "record_jti false is stateless and does not persist or flag replay" do
      private_key, jwk = generate_proof_jwk
      jti = SecureRandom.uuid
      proof = build_proof(private_key, jwk, method: "GET", uri: "http://example.com/api", jti: jti)

      assert_no_difference -> { ClientDpopProofState.count } do
        first = DpopProofValidator.new(
          proof_jwt: proof,
          request_method: "GET",
          request_uri: "http://example.com/api",
          record_jti: false,
        ).call

        assert_predicate first, :valid?

        # Same proof again still validates because uniqueness is not tracked.
        second = DpopProofValidator.new(
          proof_jwt: proof,
          request_method: "GET",
          request_uri: "http://example.com/api",
          record_jti: false,
        ).call

        assert_predicate second, :valid?
      end
    end

    test "record_jti false still requires jti claim" do
      private_key, jwk = generate_proof_jwk
      payload = { "htm" => "GET", "htu" => "http://example.com/api", "iat" => Time.current.to_i }
      proof = JWT.encode(payload, private_key, "ES256", { "typ" => "dpop+jwt", "jwk" => jwk })

      result = DpopProofValidator.new(
        proof_jwt: proof,
        request_method: "GET",
        request_uri: "http://example.com/api",
        record_jti: false,
      ).call

      assert_not result.valid?
      assert_equal "missing_jti", result.error
    end

    test "invalid signature returns error" do
      _, jwk = generate_proof_jwk
      other_key = OpenSSL::PKey::EC.generate("prime256v1")
      payload = { "htm" => "GET", "htu" => "http://example.com/api", "iat" => Time.current.to_i }
      proof = JWT.encode(payload, other_key, "ES256", { "typ" => "dpop+jwt", "jwk" => jwk })

      result = DpopProofValidator.new(
        proof_jwt: proof,
        request_method: "GET",
        request_uri: "http://example.com/api",
      ).call

      assert_not result.valid?
      assert_equal "invalid_signature", result.error
    end
  end
end
