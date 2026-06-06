# typed: false
# frozen_string_literal: true

module PreferenceAccessTokenIssuer
  extend ActiveSupport::Concern

  private

  def issue_access_token_from(preference, rotate_jti: false)
    rotate_preference_jti!(preference) if rotate_jti || preference.jti.blank?
    payload = build_preferences_payload(preference)
    write_public_option_cookies(payload)
    token = PreferenceToken.encode(
      payload,
      host: request.host,
      preference_type: preference.class.name,
      public_id: preference.public_id,
      jti: preference.jti,
      jwt_issuer_id: preference_jwt_issuer_id,
    )
    return if token.blank?

    cookies[access_token_cookie_name] =
      preference_auth_cookie_options(expires_at: PreferenceBase::ACCESS_TOKEN_TTL.from_now).merge(
        value: token,
      )

    @preference_payload = PreferenceToken.decode(token, host: request.host, jwt_issuer_id: preference_jwt_issuer_id)
    return if @preference_payload.present?

    clear_preference_auth_cookies!
    @preference_refresh_failed = true
    nil
  end

  def rotate_preference_jti!(preference)
    with_preference_connection(:writing) do
      preference.update!(jti: JitSecurityJwtJtiGenerator.generate)
    end
  end

  def preference_jwt_issuer_id
    namespace = preference_jwt_namespace
    namespace ? "surface:#{namespace}" : "preference"
  end

  def preference_jwt_namespace
    service, surface = controller_path.to_s.split("/", 3)
    return unless %w(sign acme).include?(service)

    namespace = "#{service.upcase}_#{surface.to_s.upcase}"
    namespace if JitSecurityJwtRegistry::SURFACE_NAMESPACES.include?(namespace)
  end
end
