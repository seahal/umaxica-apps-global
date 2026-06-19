# typed: false
# frozen_string_literal: true

module SignOutNotice
  extend ActiveSupport::Concern

  SIGN_OUT_NOTICE_SESSION_KEY = :sign_out_notice
  SIGN_OUT_NOTICE_TOKEN_PARAM = :ct
  SIGN_OUT_NOTICE_TOKEN_PURPOSE = "sign_out_notice"
  SIGN_OUT_NOTICE_REPLAY_PURPOSE = :sign_out_notice
  SIGN_OUT_NOTICE_TTL = 5.minutes
  SIGN_OUT_NOTICE_CACHE_CONTROL = "no-store, no-cache, must-revalidate, private"

  private

  def prepare_sign_out_completion_notice!
    @sign_out_access_expires_at = current_sign_out_access_expires_at
    @sign_out_session_public_id = current_session_public_id if respond_to?(:current_session_public_id, true)
  end

  def issue_sign_out_notice!
    @sign_out_notice_token = issue_sign_out_notice_token!
  end

  def consume_sign_out_notice
    notice = consume_sign_out_notice_token
    return unless notice

    {
      "expires_at" => notice[:expires_at],
      "access_expires_at" => notice[:access_expires_at],
      "session_public_id" => notice[:session_public_id],
    }
  end

  def sign_out_notice_cache_headers!
    response.headers["Cache-Control"] = SIGN_OUT_NOTICE_CACHE_CONTROL
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
  end

  def sign_out_completed_description
    access_expires_at = @sign_out_access_expires_at || @sign_out_notice&.fetch("access_expires_at", nil)
    return if access_expires_at.blank?

    t(
      "sign.shared.sign_out.completed_description",
      expires_at: l(access_expires_at, format: :short),
    )
  end

  def current_sign_out_access_expires_at
    access_expires_at_from_claims(Actor.authn.access_claims) ||
      access_expires_at_from_current_cookie
  end

  def access_expires_at_from_current_cookie
    return unless respond_to?(:extract_access_token, true)
    return if request&.host.blank?
    return unless respond_to?(:resource_type, true)

    token = extract_access_token(AuthenticationBase::ACCESS_COOKIE_KEY)
    return if token.blank?

    payload = AuthenticationTokenService.decode_allow_expired(
      token,
      host: request.host,
      resource_type: resource_type,
      jwt_issuer_id: auth_jwt_issuer_id_for_sign_out_notice,
    )
    access_expires_at_from_claims(payload)
  end

  def auth_jwt_issuer_id_for_sign_out_notice
    auth_jwt_issuer_id if respond_to?(:auth_jwt_issuer_id, true)
  end

  def access_expires_at_from_claims(claims)
    exp = claims&.dig("exp")
    return if exp.blank?

    Time.zone.at(Integer(exp))
  rescue ArgumentError, TypeError
    nil
  end

  def parse_sign_out_notice_time(value)
    Time.zone.iso8601(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def issue_sign_out_notice_token!
    expires_at = SIGN_OUT_NOTICE_TTL.from_now
    payload = {
      "sid" => @sign_out_session_public_id.to_s,
      "expires_at" => expires_at.iso8601,
      "access_expires_at" => @sign_out_access_expires_at&.iso8601,
      "jti" => SecureRandom.uuid,
    }

    sign_out_notice_verifier.generate(
      payload,
      purpose: SIGN_OUT_NOTICE_TOKEN_PURPOSE,
      expires_in: SIGN_OUT_NOTICE_TTL,
    )
  end

  def consume_sign_out_notice_token
    token = request&.params&.[](SIGN_OUT_NOTICE_TOKEN_PARAM)
    return unless token.present?

    payload = sign_out_notice_verifier.verified(token.to_s, purpose: SIGN_OUT_NOTICE_TOKEN_PURPOSE)
    return unless payload.is_a?(Hash)

    session_public_id = payload["sid"].to_s
    return if session_public_id.blank?
    return if respond_to?(:current_session_public_id, true) && current_session_public_id.present? &&
      current_session_public_id.to_s != session_public_id

    jti = payload["jti"].to_s
    return if jti.blank?
    return unless consume_sign_out_notice_jti!(session_public_id:, jti:)

    expires_at = parse_sign_out_notice_time(payload["expires_at"])
    return if expires_at.blank? || expires_at <= Time.current

    access_expires_at = parse_sign_out_notice_time(payload["access_expires_at"])
    {
      expires_at: expires_at,
      access_expires_at: access_expires_at,
      session_public_id: session_public_id,
    }
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  def consume_sign_out_notice_jti!(session_public_id:, jti:)
    SecurityConsumedJti.consume!(
      purpose: SecurityConsumedJti::PURPOSES.fetch(SIGN_OUT_NOTICE_REPLAY_PURPOSE),
      issuer: session_public_id,
      jti: jti,
      expires_at: SIGN_OUT_NOTICE_TTL.from_now,
    )
  rescue ActiveRecord::ActiveRecordError
    false
  end

  def sign_out_notice_verifier
    @sign_out_notice_verifier ||= ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("sign_out_notice", 32),
      digest: "SHA256",
      serializer: JSON,
      url_safe: true,
    )
  end
end
