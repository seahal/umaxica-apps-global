# typed: false
# frozen_string_literal: true

module Preference
  module WebThemeEndpoint
    extend ActiveSupport::Concern
    include Preference::Base
    include Preference::ResourceSync

    private

    def current_color_theme
      theme = theme_from_preference_payload
      theme ||= normalize_theme(cookies[Preference::Base::THEME_COOKIE_KEY])
      theme || "sy"
    end

    def theme_from_preference_payload
      payload = decoded_theme_preference_payload
      return nil if payload.blank?

      preferences = Preference::Token.extract_preferences(payload)
      normalize_theme(preferences["ct"])
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
      request_params = params.to_unsafe_h
      raw_value = request_params["theme"]
      return nil if raw_value.blank?
      return nil unless raw_value.is_a?(String)

      normalize_theme(raw_value)
    end

    def persist_theme!(short_code)
      write_preference_cookie(Preference::Base::THEME_COOKIE_KEY, short_code)

      preference = preference_for_theme_update
      return if preference.blank?

      update_preference_theme!(preference, short_code)
    end

    def preference_for_theme_update
      public_id = decoded_theme_preference_payload&.dig("public_id")
      preference = find_preference_for_theme_update(public_id) if public_id.present?
      return preference if preference.present?

      preference, = load_preference_record_from_refresh_token!(create_if_missing: true)
      preference
    end

    def find_preference_for_theme_update(public_id)
      with_preference_connection(:writing) do
        preference_class.lock.find_by(public_id: public_id)
      end
    end

    def update_preference_theme!(preference, short_code)
      with_preference_connection(:writing) do
        preference_class.transaction do
          theme = load_or_create_theme_child(preference)
          canonical = canonical_theme_option_id(
            Preference::Base::THEME_OPTION_MAP[short_code] || short_code,
          )
          option_id = lookup_option_id(
            Preference::ClassRegistry.option_class(preference_prefix, :theme),
            canonical,
          )
          return unless option_id

          resource_pref = preference_write_resource_preference!
          authorize_resource_preference_write!(resource_pref)
          write_resource_preference_option!(resource_pref, :theme, option_id) if resource_pref

          @preferences = preference
          theme.update!(option_id: option_id)
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
      jwt = matching_access_token_value
      return nil if jwt.blank?

      decode_matching_access_token(jwt)
    end

    def load_or_create_theme_child(preference)
      association_name = "#{preference.class.name.underscore}_theme"
      child = preference.public_send(association_name)
      return child if child.present?

      option_class = Preference::ClassRegistry.option_class(preference_prefix, :theme)
      preference.public_send("create_#{association_name}!", option_id: option_class::SYSTEM)
    end
  end
end
