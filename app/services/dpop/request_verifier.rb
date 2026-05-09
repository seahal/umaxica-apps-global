# typed: false
# frozen_string_literal: true

module Dpop
  class RequestVerifier
    Result =
      Struct.new(:valid, :error, keyword_init: true) do
        def valid? = valid
      end

    def initialize(access_token_payload:, proof_jwt:, request_method:, request_uri:, access_token: nil)
      @access_token_payload = access_token_payload
      @proof_jwt = proof_jwt
      @request_method = request_method
      @request_uri = request_uri
      @access_token = access_token
    end

    def call
      token_jkt = @access_token_payload&.dig("cnf", "jkt")

      # Not a DPoP-bound token; accept standard bearer
      return Result.new(valid: true, error: nil) if token_jkt.blank? && @proof_jwt.blank?

      # DPoP-bound token must present a proof
      return Result.new(valid: false, error: "missing_dpop_proof") if @proof_jwt.blank?

      proof_result = ProofValidator.new(
        proof_jwt: @proof_jwt,
        request_method: @request_method,
        request_uri: @request_uri,
        access_token: @access_token,
      ).call

      return Result.new(valid: false, error: proof_result.error) unless proof_result.valid?

      return Result.new(valid: false, error: "missing_cnf_jkt") if token_jkt.blank?

      unless token_jkt == proof_result.jkt
        return Result.new(valid: false, error: "jkt_mismatch")
      end

      Result.new(valid: true, error: nil)
    end
  end
end
