# typed: false
# frozen_string_literal: true

require "jwt"

class DpopProofVerifier
  SUPPORTED_ALGORITHMS = %w(ES256 ES384).freeze
  IAT_LEEWAY_SECONDS = 60

  Result =
    Struct.new(:valid, :error, :jwk, :jkt, keyword_init: true) do
      def valid? = valid
    end

  # record_jti:
  #   true  -- persist the jti for replay detection (login, refresh, token
  #           exchange, step-up; low-frequency, security-critical paths).
  #   false -- stateless validation with no DB write. Used for per-request API
  #           access where binding is already enforced by cnf.jkt + ath, and a
  #           write per request would be a hot-path cost. The jti claim is still
  #           required (RFC 9449, section 4.2) but its uniqueness is not tracked.
  def initialize(proof_jwt:, request_method:, request_uri:, access_token: nil, resource_type: "client",
                 record_jti: true)
    @proof_jwt = proof_jwt.to_s
    @request_method = request_method.to_s.upcase
    @request_uri = request_uri.to_s
    @access_token = access_token
    @resource_type = resource_type
    @record_jti = record_jti
  end

  def call
    header, payload, jwk = decode_and_authenticate_header
    return header if header.is_a?(Result)

    binding_error = verify_request_binding(payload)
    return binding_error if binding_error

    ath_error = verify_access_token_hash(payload)
    return ath_error if ath_error

    jkt = JitSecurityJwtThumbprintCalculator.calculate(jwk)
    replay_error = verify_jti_and_nonce(payload, jkt: jkt)
    return replay_error if replay_error

    Result.new(valid: true, error: nil, jwk: jwk, jkt: jkt)
  rescue JWT::DecodeError, OpenSSL::PKey::PKeyError, ArgumentError, JSON::ParserError
    invalid("proof_validation_error")
  end

  private

  def invalid(error)
    Result.new(valid: false, error: error)
  end

  def decode_and_authenticate_header
    return invalid("missing_proof") if @proof_jwt.blank?

    header, payload = decode_unverified
    return invalid("malformed_proof") if header.nil? || payload.nil?
    return invalid("invalid_typ") unless header["typ"] == "dpop+jwt"
    return invalid("unsupported_alg") unless SUPPORTED_ALGORITHMS.include?(header["alg"])
    return invalid("missing_jwk") if header["jwk"].blank?

    jwk = header["jwk"].to_h
    return invalid("private_key_in_jwk") if jwk["d"].present?
    return invalid("invalid_signature") unless verify_signature(header, jwk)

    [header, payload, jwk]
  end

  def verify_request_binding(payload)
    return invalid("missing_htm") if payload["htm"].blank?
    return invalid("htm_mismatch") unless payload["htm"].to_s.upcase == @request_method
    return invalid("missing_htu") if payload["htu"].blank?
    return invalid("htu_mismatch") unless htu_matches?(payload["htu"])
    return invalid("missing_iat") unless payload["iat"].is_a?(Integer)
    return invalid("iat_out_of_window") unless iat_within_window?(payload["iat"])

    nil
  end

  def verify_access_token_hash(payload)
    return nil if @access_token.blank?

    expected_ath = JitSecurityJwtThumbprintCalculator.ath(@access_token)
    return invalid("missing_ath") if payload["ath"].blank?
    return invalid("ath_mismatch") unless payload["ath"] == expected_ath

    nil
  end

  def verify_jti_and_nonce(payload, jkt:)
    # jti is REQUIRED on every proof, but its uniqueness is only persisted on
    # stateful paths (record_jti: true). Per-request validation stays stateless.
    return invalid("missing_jti") if payload["jti"].blank?

    if @record_jti
      replay_result = record_jti(payload["jti"], jkt: jkt, payload: payload)
      return replay_result unless replay_result.valid?
    end

    nonce_result = verify_nonce(payload["nonce"])
    return nonce_result unless nonce_result.valid?

    nil
  end

  def record_jti(jti, jkt:, payload:)
    return Result.new(valid: false, error: "missing_jti") if jti.blank?

    recorded = DpopJtiReplayGuard.record!(
      jti,
      resource_type: @resource_type,
      jkt: jkt,
      htm: payload["htm"],
      htu: normalize_uri(payload["htu"]),
    )
    return Result.new(valid: true, error: nil) if recorded

    Result.new(valid: false, error: "jti_replay")
  end

  def verify_nonce(nonce)
    return Result.new(valid: true, error: nil) if nonce.blank?
    return Result.new(valid: true, error: nil) if DpopNonceService.verify(nonce, resource_type: @resource_type)

    Result.new(valid: false, error: "nonce_invalid")
  end

  def decode_unverified
    segments = @proof_jwt.split(".")
    return [nil, nil] unless segments.size == 3

    header = JSON.parse(Base64.urlsafe_decode64(pad_base64(segments[0])))
    payload = JSON.parse(Base64.urlsafe_decode64(pad_base64(segments[1])))
    [header, payload]
  rescue ArgumentError, JSON::ParserError
    [nil, nil]
  end

  def pad_base64(str)
    str += "=" * (4 - (str.length % 4)) unless str.length % 4 == 0
    str
  end

  def verify_signature(header, jwk)
    algorithm = header["alg"]
    jwk_obj = JWT::JWK.import(jwk)
    JWT.decode(
      @proof_jwt, jwk_obj.public_key, true, {
        algorithms: [algorithm],
        verify_expiration: false,
        verify_not_before: false,
      },
    )
    true
  rescue JWT::VerificationError, JWT::DecodeError
    false
  end

  def htu_matches?(htu)
    normalize_uri(@request_uri) == normalize_uri(htu)
  rescue URI::Error
    false
  end

  def normalize_uri(uri_string)
    uri = URI.parse(uri_string)
    port_part =
      if uri.port.present? && uri.port != uri.default_port
        ":#{uri.port}"
      else
        ""
      end
    "#{uri.scheme}://#{uri.host}#{port_part}#{uri.path}"
  end

  def iat_within_window?(iat)
    now = Time.current.to_i
    (iat - IAT_LEEWAY_SECONDS) <= now && now <= (iat + IAT_LEEWAY_SECONDS)
  end
end
