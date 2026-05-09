# typed: false
# frozen_string_literal: true

require "jwt"

module Preference
  module WebCookieEndpoint
    extend ActiveSupport::Concern
    include Preference::ConsentedBuffer

    private

    def cookie_consent_state
      payload = decoded_preference_payload
      preferences = payload.is_a?(Hash) ? payload["preferences"] : nil

      if preferences.is_a?(Hash)
        {
          consented: ActiveModel::Type::Boolean.new.cast(preferences["consented"]),
          functional: ActiveModel::Type::Boolean.new.cast(preferences["functional"]),
          performant: ActiveModel::Type::Boolean.new.cast(preferences["performant"]),
          targetable: ActiveModel::Type::Boolean.new.cast(preferences["targetable"]),
        }
      else
        { consented: false, functional: false, performant: false, targetable: false }
      end
    rescue StandardError => e
      Rails.logger.warn("[Preference::WebCookieEndpoint] cookie_consent_state fallback: #{e.class}")
      { consented: false, functional: false, performant: false, targetable: false }
    end

    def show_banner?
      false
    end

    def set_consented_buffer_cookie!
      set_preference_consented_buffer!(
        consented: extract_cookie_consented(decoded_preference_payload),
        expires_at: refresh_token_expires_at || Preference::Base::REFRESH_TOKEN_TTL.from_now,
      )
    end

    def sync_consented_buffer_cookie_safely!
      set_consented_buffer_cookie!
    rescue StandardError => e
      Rails.logger.warn("[Preference::WebCookieEndpoint] buffer sync skipped: #{e.class}")
    end

    def apply_consented_update_from_request!
      requested = requested_consented_value
      return false if requested.nil?

      persist_cookie_consent!(requested)
      true
    rescue StandardError => e
      Rails.logger.error("[Preference::WebCookieEndpoint] consent update failed: #{e.class}")
      raise
    end

    # SSOT decode point.
    def decode_and_verify_preference_jwt(jwt)
      payload = Preference::Token.decode(jwt, host: request.host)
      return payload if payload.is_a?(Hash)

      Rails.logger.info(I18n.t("errors.preference.cookie.invalid_access_token"))
      nil
    end

    def extract_cookie_consented(payload)
      return false unless payload.is_a?(Hash)

      preferences = payload["preferences"]
      return false unless preferences.is_a?(Hash)

      ActiveModel::Type::Boolean.new.cast(preferences["consented"])
    end

    def decoded_preference_payload
      @decoded_preference_payload ||=
        begin
          jwt = cookies[Preference::CookieName.access]
          decode_and_verify_preference_jwt(jwt)
        end
    end

    def refresh_token_expires_at
      public_id = decoded_preference_payload&.dig("public_id")
      record = find_preference_by_public_id(public_id)
      return record.expires_at if record&.expires_at.present?

      nil
    rescue StandardError => e
      Rails.logger.warn("[Preference::WebCookieEndpoint] refresh expiry fallback: #{e.class}")
      nil
    end

    def find_preference_by_public_id(public_id)
      return nil if public_id.blank?

      with_preference_connection(:reading) do
        preference_class.find_by(public_id: public_id)
      end
    end

    def preference_class
      @preference_class ||= Preference::ClassRegistry.for_controller_path(controller_path)
    end

    def refresh_token_value
      params[Preference::IoKeys::Params::REFRESH_TOKEN].presence || cookies[Preference::CookieName.refresh]
    end

    def requested_consented_value
      raw_value =
        if params.key?(:consented)
          params[:consented]
        elsif params.expect(:cookie).is_a?(Hash) && params.expect(:cookie).key?(:consented)
          params[:cookie][:consented]
        else
          return nil
        end
      ActiveModel::Type::Boolean.new.cast(raw_value)
    end

    def persist_cookie_consent!(consented)
      public_id = decoded_preference_payload&.dig("public_id")
      return if public_id.blank?

      with_preference_connection(:writing) do
        preference_class.transaction do
          preference = preference_class.lock.find_by(public_id: public_id)
          return if preference.blank?

          cookie = load_or_create_preference_cookie!(preference)
          attrs = { consented: consented }
          attrs[:consented_at] = consented ? (cookie.consented_at || Time.current) : nil
          cookie.update!(attrs)

          preference.reload
          issue_access_token_from(preference)
          raise RuntimeError, "failed_to_issue_preference_access_token" if @preference_payload.blank?

          @decoded_preference_payload = nil
        end
      end
    end

    def load_or_create_preference_cookie!(preference)
      association_name = "#{preference.class.name.underscore}_cookie"
      cookie = preference.public_send(association_name)
      return cookie if cookie.present?

      default_attrs = {
        targetable: false,
        performant: false,
        functional: false,
        consented: false,
      }
      preference.public_send("create_#{association_name}!", default_attrs)
    end
  end
end
