# typed: false
# frozen_string_literal: true

module Preference::AccessTokenTransport
  extend ActiveSupport::Concern

  private

  def load_access_token_payload
    token = matching_access_token_value
    return false if token.blank?

    payload = decode_matching_access_token(token)
    return false if payload.blank?

    @preference_payload = payload

    public_id = Preference::Token.extract_public_id(payload)
    if public_id.present?
      operation =
        lambda do
          with_preference_connection(:writing) do
            preference_class.includes(preference_associations_to_preload).find_by(public_id: public_id)
          end
        end
      @preferences = defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
      return false unless keep_loaded_access_token_payload?(payload)
    end

    true
  end

  def keep_loaded_access_token_payload?(payload)
    if @preferences.blank?
      cookies.delete(access_token_cookie_name, **preference_cookie_deletion_options)
      @preference_payload = nil
      return false
    end

    return true if preference_access_token_current?(@preferences, payload)

    cookies.delete(access_token_cookie_name, **preference_cookie_deletion_options)
    @preferences = nil
    @preference_payload = nil
    false
  end

  def preference_access_token_current?(preference, payload)
    current_jti = preference&.jti
    return true if current_jti.blank?

    payload_jti = Preference::Token.extract_jti(payload)
    return false if payload_jti.blank?

    secure_compare?(current_jti, payload_jti)
  end

  def matching_access_token_value
    access_token_cookie_names.lazy.filter_map do |cookie_name|
      token = cookies[cookie_name].to_s.presence
      next if token.blank?

      payload = decode_matching_access_token(token)
      next if payload.blank?

      @preference_payload = payload
      token
    end.first
  end

  def decode_matching_access_token(token)
    payload = Preference::Token.decode(token, host: request.host)
    return if payload.blank?
    return if Preference::Token.extract_preference_type(payload) != preference_class.name

    payload
  end
end
