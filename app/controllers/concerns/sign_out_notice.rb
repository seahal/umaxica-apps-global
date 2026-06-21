# typed: false
# frozen_string_literal: true

module SignOutNotice
  extend ActiveSupport::Concern

  included do
    helper_method :sign_out_active_context_present?,
                  :sign_out_confirmation_form_path,
                  :sign_out_home_path,
                  :sign_out_completed_description
  end

  SIGN_OUT_NOTICE_SESSION_KEY = :sign_out_notice
  SIGN_OUT_NOTICE_TTL = 5.minutes
  SIGN_OUT_NOTICE_CACHE_CONTROL = "no-store, no-cache, must-revalidate, private"

  private

  def prepare_sign_out_completion_notice!(state: nil)
    @sign_out_access_expires_at = current_sign_out_access_expires_at
    @sign_out_session_public_id = current_session_public_id if respond_to?(:current_session_public_id, true)
    @sign_out_state = state
  end

  def issue_sign_out_notice!
    session[SIGN_OUT_NOTICE_SESSION_KEY] = sign_out_notice_payload
    @sign_out_notice = sign_out_notice_from_session(session[SIGN_OUT_NOTICE_SESSION_KEY])
  end

  def consume_sign_out_notice
    notice = session[SIGN_OUT_NOTICE_SESSION_KEY]
    return unless notice.is_a?(Hash)

    parsed = sign_out_notice_from_session(notice)
    return unless parsed

    session.delete(SIGN_OUT_NOTICE_SESSION_KEY)
    parsed
  end

  def sign_out_completion_notice_present?
    session.key?(SIGN_OUT_NOTICE_SESSION_KEY)
  end

  def sign_out_active_context_present?
    return true if current_resource.present? || current_session_public_id.present?
    return true if respond_to?(:oidc_logout_pending_request_present?, true) && oidc_logout_pending_request_present?

    false
  end

  def sign_out_route_helper_prefix
    controller_path.split("/").first(2).join("_")
  end

  def sign_out_route_params
    params.permit(:ri).to_h.symbolize_keys
  end

  def sign_out_new_path
    public_send("new_#{sign_out_route_helper_prefix}_sign_out_path", **sign_out_route_params)
  end

  def sign_out_new_url
    public_send("new_#{sign_out_route_helper_prefix}_sign_out_url", **sign_out_route_params)
  end

  def sign_out_edit_path
    public_send("edit_#{sign_out_route_helper_prefix}_sign_out_path", **sign_out_route_params)
  end

  def sign_out_edit_url
    public_send("edit_#{sign_out_route_helper_prefix}_sign_out_url", **sign_out_route_params)
  end

  def sign_out_post_path
    public_send("#{sign_out_route_helper_prefix}_sign_out_path", **sign_out_route_params)
  end

  def sign_out_post_url
    public_send("#{sign_out_route_helper_prefix}_sign_out_url", **sign_out_route_params)
  end

  def sign_out_complete_path
    public_send("complete_#{sign_out_route_helper_prefix}_sign_out_path", **sign_out_route_params)
  end

  def sign_out_complete_url
    public_send("complete_#{sign_out_route_helper_prefix}_sign_out_url", **sign_out_route_params)
  end

  def sign_out_home_path
    public_send("#{sign_out_route_helper_prefix}_root_path", **sign_out_route_params)
  end

  def sign_out_home_url
    public_send("#{sign_out_route_helper_prefix}_root_url", **sign_out_route_params)
  end

  def sign_out_confirmation_form_path
    sign_out_post_path
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

  def sign_out_notice_payload
    expires_at = SIGN_OUT_NOTICE_TTL.from_now
    payload = {
      "sid" => @sign_out_session_public_id.presence,
      "expires_at" => expires_at.iso8601,
      "access_expires_at" => @sign_out_access_expires_at&.iso8601,
      "state" => @sign_out_state,
    }

    payload.compact
  end

  def sign_out_notice_from_session(payload)
    expires_at = parse_sign_out_notice_time(payload["expires_at"])
    return if expires_at.blank? || expires_at <= Time.current

    access_expires_at = parse_sign_out_notice_time(payload["access_expires_at"])
    {
      expires_at: expires_at,
      access_expires_at: access_expires_at,
      session_public_id: payload["sid"].presence,
      state: payload["state"].presence,
    }
  end
end
