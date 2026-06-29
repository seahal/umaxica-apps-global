# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

module Dpop
  class RequestVerifierTest < ActiveSupport::TestCase
    def generate_proof_jwk
      ec = OpenSSL::PKey::EC.generate("prime256v1")
      jwk = JWT::JWK.new(ec)
      [ec, jwk.export]
    end

    def build_proof(private_key, jwk, method:, uri:)
      payload = { "htm" => method, "htu" => uri, "iat" => Time.current.to_i, "jti" => SecureRandom.uuid }
      JWT.encode(payload, private_key, "ES256", { "typ" => "dpop+jwt", "jwk" => jwk })
    end

    test "accepts standard bearer when no cnf.jkt and no proof" do
      payload = { "sub" => 1 }
      result = DpopRequestVerifier.new(
        access_token_payload: payload,
        proof_jwt: nil,
        request_method: "GET",
        request_uri: "http://example.com/api",
      ).call

      assert_predicate result, :valid?
    end

    test "rejects dpop-bound token without proof" do
      payload = { "sub" => 1, "cnf" => { "jkt" => "abc" } }
      result = DpopRequestVerifier.new(
        access_token_payload: payload,
        proof_jwt: nil,
        request_method: "GET",
        request_uri: "http://example.com/api",
      ).call

      assert_not result.valid?
      assert_equal "missing_dpop_proof", result.error
    end

    test "accepts valid dpop proof with matching jkt" do
      private_key, jwk = generate_proof_jwk
      proof = build_proof(private_key, jwk, method: "GET", uri: "http://example.com/api")
      jkt = JitSecurityJwtThumbprintCalculator.calculate(jwk)
      payload = { "sub" => 1, "cnf" => { "jkt" => jkt } }

      result = DpopRequestVerifier.new(
        access_token_payload: payload,
        proof_jwt: proof,
        request_method: "GET",
        request_uri: "http://example.com/api",
      ).call

      assert_predicate result, :valid?
    end

    test "rejects dpop proof with mismatched jkt" do
      private_key, jwk = generate_proof_jwk
      proof = build_proof(private_key, jwk, method: "GET", uri: "http://example.com/api")
      payload = { "sub" => 1, "cnf" => { "jkt" => "different_jkt" } }

      result = DpopRequestVerifier.new(
        access_token_payload: payload,
        proof_jwt: proof,
        request_method: "GET",
        request_uri: "http://example.com/api",
      ).call

      assert_not result.valid?
      assert_equal "jkt_mismatch", result.error
    end

    test "rejects when proof validation fails" do
      payload = { "sub" => 1, "cnf" => { "jkt" => "abc" } }
      result = DpopRequestVerifier.new(
        access_token_payload: payload,
        proof_jwt: "invalid.proof.jwt",
        request_method: "GET",
        request_uri: "http://example.com/api",
      ).call

      assert_not result.valid?
      assert_equal "malformed_proof", result.error
    end
  end
end
