# typed: false
# frozen_string_literal: true

module Preference::AccessTokenIssuer
  extend ActiveSupport::Concern

  private

  def issue_access_token_from(preference)
    rotate_preference_jti!(preference)
    payload = build_preferences_payload(preference)
    token = Preference::Token.encode(
      payload,
      host: request.host,
      preference_type: preference.class.name,
      public_id: preference.public_id,
      jti: preference.jti,
    )
    return if token.blank?

    cookies[access_token_cookie_name] =
      preference_auth_cookie_options(expires_at: Preference::Base::ACCESS_TOKEN_TTL.from_now).merge(
        value: token,
      )

    @preference_payload = Preference::Token.decode(token, host: request.host)
    return if @preference_payload.present?

    clear_preference_auth_cookies!
    @preference_refresh_failed = true
    nil
  end

  def rotate_preference_jti!(preference)
    with_preference_connection(:writing) do
      preference.update!(jti: Jit::Security::Jwt::JtiGenerator.generate)
    end
  end
end
