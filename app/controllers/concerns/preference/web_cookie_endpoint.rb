# typed: false
# frozen_string_literal: true

require "jwt"

module Preference
  module WebCookieEndpoint
    extend ActiveSupport::Concern
    include Preference::Base
    include Preference::ConsentedBuffer
    include Preference::ResourceSync

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
      payload = decode_matching_access_token(jwt)
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
          jwt = matching_access_token_value
          decode_and_verify_preference_jwt(jwt)
        end
    end

    def refresh_token_expires_at
      public_id = decoded_preference_payload&.dig("public_id")
      record = find_preference_by_public_id(public_id)
      expires_at = record&.expires_at
      return expires_at if expires_at.present? && !expires_at.is_a?(Float)

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
      params[Preference::IoKeys::Params::REFRESH_TOKEN].presence || cookies[refresh_token_cookie_name]
    end

    def requested_consented_value
      return ActiveModel::Type::Boolean.new.cast(params[:consented]) if params.key?(:consented)

      cookie_params = params[:cookie]
      return nil unless cookie_params.is_a?(ActionController::Parameters) || cookie_params.is_a?(Hash)

      cookie_params = cookie_params.to_h.with_indifferent_access
      return nil unless cookie_params.key?(:consented)

      raw_value = cookie_params[:consented]
      ActiveModel::Type::Boolean.new.cast(raw_value)
    end

    def persist_cookie_consent!(consented)
      public_id = decoded_preference_payload&.dig("public_id")
      raise RuntimeError, "missing_preference_access_token" if public_id.blank?

      with_preference_connection(:writing) do
        preference_class.transaction do
          preference = preference_class.lock.find_by(public_id: public_id)
          raise ActiveRecord::RecordNotFound, "preference_not_found" if preference.blank?

          @preferences = preference
          cookie = load_or_create_preference_cookie!(preference)
          attrs = { consented: consented }
          attrs[:consented_at] = consented ? (cookie.consented_at || Time.current) : nil

          resource_pref = preference_write_resource_preference!
          authorize_resource_preference_write!(resource_pref)
          write_resource_preference_cookie!(resource_pref, attrs) if resource_pref

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
