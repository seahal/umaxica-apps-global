# typed: false
# frozen_string_literal: true

module Preference
  module WebThemeEndpoint
    extend ActiveSupport::Concern
    include Preference::Base

    private

    def current_color_theme
      theme = normalize_colortheme(cookies[Preference::Base::THEME_COOKIE_KEY])
      theme ||= theme_from_preference_payload
      theme || "sy"
    end

    def theme_from_preference_payload
      payload = decoded_theme_preference_payload
      return nil if payload.blank?

      preferences = Preference::Token.extract_preferences(payload)
      normalize_colortheme(preferences["ct"])
    end

    def apply_theme_update_from_request!
      requested = requested_theme_value
      return nil if requested.nil?

      persist_theme!(requested)
      requested
    rescue StandardError => e
      Rails.logger.error("[Preference::WebThemeEndpoint] theme update failed: #{e.class}")
      raise
    end

    def requested_theme_value
      raw_value =
        if params[:theme].is_a?(String)
          params[:theme]
        elsif params.key?(:ct)
          params[:ct]
        else
          return nil
        end
      normalize_colortheme(raw_value.to_s)
    end

    def persist_theme!(short_code)
      write_preference_cookie(Preference::Base::THEME_COOKIE_KEY, short_code)

      public_id = decoded_theme_preference_payload&.dig("public_id")
      return if public_id.blank?

      preference = find_preference_for_theme_update(public_id)
      return if preference.blank?

      update_preference_colortheme!(preference, short_code)
    end

    def find_preference_for_theme_update(public_id)
      with_preference_connection(:writing) do
        preference_class.lock.find_by(public_id: public_id)
      end
    end

    def update_preference_colortheme!(preference, short_code)
      with_preference_connection(:writing) do
        preference_class.transaction do
          colortheme = load_or_create_colortheme_child(preference)
          canonical = canonical_colortheme_option_id(
            Preference::Base::COLORTHEME_OPTION_MAP[short_code] || short_code,
          )
          option_id = lookup_option_id(
            Preference::ClassRegistry.option_class(preference_prefix, :colortheme),
            canonical,
          )
          return unless option_id

          @preferences = preference
          colortheme.update!(option_id: option_id)
          create_audit_log(
            event_id: "UPDATE_PREFERENCE_COLORTHEME",
            context: { updated_attributes: { option_id: option_id }, source: "web_theme_endpoint" },
          )

          preference.reload
          issue_access_token_from(preference)
          raise RuntimeError, "failed_to_issue_preference_access_token" if @preference_payload.blank?
        end
      end
    end

    def decoded_theme_preference_payload
      @decoded_theme_preference_payload ||= decode_theme_jwt
    end

    def decode_theme_jwt
      jwt = cookies[Preference::CookieName.access]
      return nil if jwt.blank?

      Preference::Token.decode(jwt, host: request.host)
    end

    def load_or_create_colortheme_child(preference)
      association_name = "#{preference.class.name.underscore}_colortheme"
      child = preference.public_send(association_name)
      return child if child.present?

      option_class = Preference::ClassRegistry.option_class(preference_prefix, :colortheme)
      preference.public_send("create_#{association_name}!", option_id: option_class::SYSTEM)
    end
  end
end
