# typed: false
# frozen_string_literal: true

class DpopRequestVerifier
  Result =
    Struct.new(:valid, :error, keyword_init: true) do
      def valid? = valid
    end

  def initialize(access_token_payload:, proof_jwt:, request_method:, request_uri:, access_token: nil,
                 resource_type: "client")
    @access_token_payload = access_token_payload
    @proof_jwt = proof_jwt
    @request_method = request_method
    @request_uri = request_uri
    @access_token = access_token
    @resource_type = resource_type
  end

  def call
    token_jkt = @access_token_payload&.dig("cnf", "jkt")

    # Not a DPoP-bound token; accept standard bearer
    return Result.new(valid: true, error: nil) if token_jkt.blank? && @proof_jwt.blank?

    # DPoP-bound token must present a proof
    return Result.new(valid: false, error: "missing_dpop_proof") if @proof_jwt.blank?

    # Per-request API access must consume the proof jti. cnf.jkt + ath bind the
    # proof to the token, but they do not stop replay of a stolen proof.
    proof_result = DpopProofValidator.new(
      proof_jwt: @proof_jwt,
      request_method: @request_method,
      request_uri: @request_uri,
      access_token: @access_token,
      resource_type: @resource_type,
      record_jti: true,
    ).call

    return Result.new(valid: false, error: proof_result.error) unless proof_result.valid?

    return Result.new(valid: false, error: "missing_cnf_jkt") if token_jkt.blank?

    unless token_jkt == proof_result.jkt
      return Result.new(valid: false, error: "jkt_mismatch")
    end

    Result.new(valid: true, error: nil)
  end
end
