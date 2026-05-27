# typed: false
# frozen_string_literal: true

require "sha3"
require "concurrent"

module Preference
  class ResolutionError < StandardError; end

  # ==========================================================================
  # TOC
  # 1) Preference request entrypoints (I/O boundary)
  # 2) Preference option/domain mapping
  # 3) Audit + preference domain updates
  # 4) Refresh/access token lifecycle (I/O + domain)
  # 5) Cookie/header/session helpers (I/O boundary)
  # 6) Child-record lazy helpers
  #
  # JWT key resolution → Preference::JwtConfiguration (jwt_configuration.rb)
  # Token encode/decode → Preference::Token (token.rb)
  # Audit-event name → ID → Preference::ClassRegistry.audit_event_id_for
  # ==========================================================================

  module Base
    extend ActiveSupport::Concern
    include RefreshTokenShared
    include Preference::CookieWriter
    include Preference::AccessTokenTransport
    include Preference::AccessTokenIssuer
    include Preference::RefreshTokenTransport
    include Preference::Transport

    ACCESS_TOKEN_TTL = 7.days
    REFRESH_TOKEN_TTL = 400.days
    THEME_COOKIE_KEY = Preference::IoKeys::Cookies::THEME
    LANGUAGE_COOKIE_KEY = Preference::IoKeys::Cookies::LANGUAGE
    TIMEZONE_COOKIE_KEY = Preference::IoKeys::Cookies::TIMEZONE

    COLORTHEME_SHORT_MAP = {
      "light" => "li",
      "dark" => "dr",
      "system" => "sy",
    }.freeze
    THEME_SHORT_MAP = COLORTHEME_SHORT_MAP

    COLORTHEME_OPTION_MAP = {
      "li" => "light",
      "dr" => "dark",
      "sy" => "system",
      "light" => "light",
      "dark" => "dark",
      "system" => "system",
    }.freeze
    THEME_OPTION_MAP = COLORTHEME_OPTION_MAP

    def show_cookie_banner?
      false
    end

    private

    def preference_current_resource
      return unless respond_to?(:current_resource, true)

      current_resource
    rescue StandardError => e
      raise_preference_resolution_error!(:current_resource, e)
    end

    def raise_preference_resolution_error!(component, exception)
      Rails.logger.warn(
        LogEvent.format(
          "preference.resolution.failed",
          component: component,
          error_class: exception.class.name,
        ),
      )

      raise ResolutionError.new("Preference #{component} resolution failed"), cause: exception
    end

    # ==========================================================================
    # 2) Preference request entrypoints (Request/Cookie I/O boundary)
    # ==========================================================================
    def cookie_banner_endpoint_url
      return nil unless cookie_banner_endpoint_available_for_request?

      @cookie_banner_endpoint_url ||=
        begin
          endpoint_url = nil
          %i(
            apex_app_web_v0_cookie_url
            apex_com_web_v0_cookie_url
            apex_org_web_v0_cookie_url
          ).each do |helper_name|
            next unless respond_to?(helper_name, true)

            endpoint_url = public_send(helper_name)
            break
          rescue ActionController::UrlGenerationError
            next
          end
          endpoint_url
        end
    end

    def cookie_banner_endpoint_available_for_request?
      expected_host =
        case ::Core::Surface.current(request)
        when :app then ENV["APEX_SERVICE_URL"]
        when :com then ENV["APEX_CORPORATE_URL"]
        when :org then ENV["APEX_STAFF_URL"]
        end
      return false if expected_host.blank?

      request.host == expected_host
    end

    def extract_cookie_banner_consent(payload)
      return nil unless payload.is_a?(Hash)

      preferences = payload["preferences"]
      return nil unless preferences.is_a?(Hash)
      return preferences["consent"] if preferences.key?("consent")
      return preferences["consented"] if preferences.key?("consented")

      nil
    end

    def set_color_theme
      theme = normalize_colortheme(actor_preference_theme)
      theme ||= "sy"

      write_preference_cookie(THEME_COOKIE_KEY, theme)
      @color_theme = theme
      nil
    end

    def actor_preference_theme
      preference = Actor.preferences
      return if preference.null?

      preference.theme
    end

    def preference_record_theme
      return if @preferences.blank?

      option_id = @preferences.public_send(preference_colortheme_association)&.option_id
      colortheme_short_code(option_id_to_colortheme(option_id, preference_prefix))
    end

    def create_preference_options(preference, params_hash = {})
      prefix = preference_prefix(preference)
      option_ids = preference_option_ids(prefix, params_hash)

      create_preference_cookie(prefix, preference)
      ensure_preference_option_defaults(prefix)
      create_preference_option_records(prefix, preference, option_ids)
    end

    # ==========================================================================
    # 3) Preference option/domain mapping
    # ==========================================================================
    def preference_option_ids(prefix, params_hash)
      Preference::ClassRegistry::CHILD_RECORD_TYPES.index_with do |type|
        resolve_option_id_from_param(
          preference_param_value(params_hash, type),
          type,
          Preference::ClassRegistry.default_option_id(prefix, type),
          prefix,
        )
      end
    end

    def preference_option_classes(prefix)
      classes =
        Preference::ClassRegistry::CHILD_RECORD_TYPES.index_with do |type|
          Preference::ClassRegistry.option_class(prefix, type)
        end
      classes[:colortheme] = classes[:theme]
      classes
    end

    def create_preference_cookie(prefix, preference)
      klass = Preference::ClassRegistry.cookie_class(prefix)
      with_model_writing_connection(klass) do
        create_preference_association!(
          preference,
          "#{prefix.underscore}_preference_cookie",
          targetable: false,
          performant: false,
          functional: false,
          consented: false,
        )
      end
    end

    def ensure_preference_option_defaults(prefix)
      Preference::ClassRegistry::CHILD_RECORD_TYPES.each do |type|
        klass = Preference::ClassRegistry.option_class(prefix, type)
        ensure_model_defaults!(klass)
      end
    end

    def create_preference_option_records(prefix, preference, option_ids)
      Preference::ClassRegistry::CHILD_RECORD_TYPES.each do |type|
        klass = Preference::ClassRegistry.record_class(prefix, type)
        with_model_writing_connection(klass) do
          create_preference_association!(
            preference,
            "#{prefix.underscore}_preference_#{type}",
            option_id: option_ids[type],
          )
        end
      end
    end

    def create_preference_association!(preference, association_name, attributes)
      creator = :"create_#{association_name}!"
      return preference.public_send(creator, attributes) if preference.respond_to?(creator)

      association = preference.association(association_name.to_sym)
      association.klass.create!(attributes.merge(preference: preference))
    end

    def preference_param_value(params_hash, type)
      case type
      when :language then params_hash[:lx]
      when :region then params_hash[:ri]
      when :timezone then params_hash[:tz]
      when :theme then params_hash[:ct]
      else params_hash[type]
      end
    end

    def resolve_option_id_from_param(value, type, default, _prefix)
      return default if value.blank?

      sanitized = sanitize_option_id({ option_id: value }, option_type: type)
      if sanitized[:option_id].is_a?(Integer)
        sanitized[:option_id]
      else
        default
      end
    end

    def set_locale_from_params
      locale = normalized_locale(params[Preference::IoKeys::Params::LX])
      locale ||= normalized_locale(cookies[LANGUAGE_COOKIE_KEY])
      locale ||= normalized_locale(preference_payload_value("lx"))
      locale ||= locale_from_region(params[Preference::IoKeys::Params::RI])
      locale ||= locale_from_region(preference_payload_value("ri"))
      locale ||= I18n.default_locale

      I18n.locale = locale
    end

    def locale_from_region(region)
      return if region.blank?

      {
        "jp" => "ja",
        "us" => "en",
      }[region]
    end

    def normalized_locale(value)
      return if value.blank?

      normalized_value = value.to_s.downcase
      return if normalized_value.blank?

      return unless available_locale_strings.include?(normalized_value)

      normalized_value.to_sym
    end

    def available_locale_strings
      @available_locale_strings ||=
        begin
          locales = I18n.available_locales.map { |locale| locale.to_s.downcase }
          locales.uniq!
          locales
        end
    end

    def set_timezone_from_session
      Time.zone = session[:timezone] if session[:timezone].present?
    end

    def preference_class
      @preference_class ||=
        begin
          Preference::ClassRegistry.for_controller_path(controller_path)
        end
    end

    def preference_audit_class
      @preference_audit_class ||= Preference::ClassRegistry.audit_class_for(preference_class)
    end

    def preference_audit_event_class
      @preference_audit_event_class ||= Preference::ClassRegistry.audit_event_class_for(preference_class)
    end

    def preference_audit_level_class
      @preference_audit_level_class ||= Preference::ClassRegistry.audit_level_class_for(preference_class)
    end

    def preference_status_class
      @preference_status_class ||= Preference::ClassRegistry.status_class_for(preference_class)
    end

    # ==========================================================================
    # 4) Audit + preference domain updates
    # ==========================================================================
    def normalize_preference_audit_event_id(event_id)
      return if event_id.blank?

      Preference::ClassRegistry.audit_event_id_for(preference_audit_event_class, event_id)
    end

    def ensure_preferences_record
      load_access_token_preference_record!
      return @preferences if @preferences.present?

      preference, = load_preference_record_from_refresh_token!(create_if_missing: true)
      if preference.present?
        @preferences = preference
        return @preferences
      end
      return create_new_preference_record! unless @preference_refresh_failed

      @preference_refresh_failed = false
      @refresh_token_value = nil
      @refresh_presented_digest = nil
      @refresh_public_id = nil
      create_new_preference_record!
    end

    def create_audit_log(event_id:, context:, expires_at: nil)
      expires_at_value = expires_at || REFRESH_TOKEN_TTL.from_now
      normalized_event_id = normalize_preference_audit_event_id(event_id)

      ChronicleRecord.connected_to(role: :writing) do
        ensure_model_defaults!(preference_audit_level_class)

        if normalized_event_id.present?
          preference_audit_event_class.find_or_create_by!(id: normalized_event_id)
        end

        preference_audit_class.create!(
          subject_id: @preferences.id.to_s,
          subject_type: @preferences.class.name,
          event_id: normalized_event_id,
          level_id: preference_audit_level_class::INFO,
          occurred_at: Time.current,
          discarded_at: expires_at_value,
          ip_address: request.remote_ip || default_audit_ip,
          context: context,
        )
      end
    end

    def preference_prefix(preference = nil)
      return preference.class.name.gsub("Preference", "") if preference.present?

      @preference_prefix ||= preference_class.name.gsub("Preference", "")
    end

    def preference_prefix_underscore
      @preference_prefix_underscore ||= preference_class.name.underscore
    end

    def default_audit_ip
      IPAddr.new((127 << 24) + 1).to_s
    end

    def preference_colortheme_association
      @preference_colortheme_association ||= "#{preference_prefix_underscore}_colortheme"
    end

    def update_preference_child_with_audit(child, attributes, audit_event)
      return if child.blank? || attributes.blank?

      # Ensure nested params are a Hash with indifferent access for reliable key access.
      # Note: Rails 8 `expect` returns an ActionController::Parameters object,
      # which we want to convert to Hash with indifferent access after ensuring it's permitted.
      p_hash = attributes.to_h.with_indifferent_access

      preference_connection_owner.transaction do
        child.update!(p_hash)
        create_audit_log(
          event_id: audit_event,
          context: { updated_attributes: p_hash },
        )
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("#{audit_event} failed: #{e.message}")
      raise PreferenceOperationError
    end

    def sanitize_option_id(params, option_type: nil)
      params[Preference::IoKeys::Params::OPTION_ID] = nil if params[Preference::IoKeys::Params::OPTION_ID].blank?

      return params if params[Preference::IoKeys::Params::OPTION_ID].blank?

      # If option_id is already an integer, use it as-is
      option_id_key = Preference::IoKeys::Params::OPTION_ID
      if option_type != :items_per_page &&
          (params[option_id_key].is_a?(Integer) || params[option_id_key].to_s.match?(/^\d+$/))
        params[option_id_key] = Integer(params[option_id_key].to_s, 10)
        return params
      end

      prefix = preference_class.name.delete_suffix("Preference")
      option_class = Preference::ClassRegistry.option_class(prefix, option_type) if option_type

      if option_class
        name =
          if %i(colortheme theme).include?(option_type)
            canonical_colortheme_option_id(params[option_id_key])
          else
            params[option_id_key]
          end
        resolved_option_id = lookup_option_id(option_class, name)
        params[option_id_key] = resolved_option_id if resolved_option_id
      end
      params
    end

    def lookup_option_id(option_class, raw_name)
      return if option_class.blank? || raw_name.blank?

      target_keys = normalized_option_lookup_keys(raw_name)
      option_class.find_each do |option|
        return option.id if (target_keys & normalized_option_lookup_keys(option.name)).any?
      end
      nil
    end

    def normalized_option_lookup_keys(value)
      normalized = value.to_s
      [
        normalized.downcase,
        normalized.upcase.tr("/", "_").tr("-", "_").downcase,
      ].uniq
    end

    def canonical_colortheme_option_id(value)
      return nil if value.blank?

      COLORTHEME_OPTION_MAP[value.to_s.downcase]
    end

    def colortheme_short_code(value)
      return nil if value.blank?

      COLORTHEME_SHORT_MAP[value.to_s.downcase]
    end

    def normalize_colortheme(value)
      return nil if value.blank?

      theme = value.to_s.downcase
      if COLORTHEME_SHORT_MAP.value?(theme)
        theme
      else
        COLORTHEME_SHORT_MAP[theme]
      end
    end

    def ensure_preference_reference_defaults!
      ensure_model_defaults!(Preference::ClassRegistry.status_class_for(preference_class))
      ensure_model_defaults!(preference_audit_level_class)
      ensure_model_defaults!(preference_audit_event_class)
      ensure_model_defaults!(preference_binding_method_class)
      ensure_model_defaults!(preference_dbsc_status_class)
    end

    def ensure_model_defaults!(klass)
      return if klass.blank? || !klass.respond_to?(:ensure_defaults!)

      connection_owner = model_connection_owner(klass)
      if connection_owner.blank?
        klass.ensure_defaults!
        return
      end

      connection_owner.connected_to(role: :writing) do
        klass.ensure_defaults!
      end
    end

    def with_model_writing_connection(klass)
      connection_owner = model_connection_owner(klass)
      return yield if connection_owner.blank?

      connection_owner.connected_to(role: :writing) { yield }
    end

    def model_connection_owner(klass)
      klass.ancestors.find do |ancestor|
        ancestor.is_a?(Class) && ancestor < ActiveRecord::Base && ancestor.abstract_class?
      end
    end

    def preference_connection_owner
      @preference_connection_owner ||=
        preference_class.ancestors.find do |ancestor|
          ancestor.is_a?(Class) && ancestor < ActiveRecord::Base && ancestor.abstract_class?
        end
    end

    def with_preference_connection(role)
      connection_owner = preference_connection_owner
      return yield if connection_owner.blank?

      connection_owner.connected_to(role: role) { yield }
    end

    # ==========================================================================
    # 5) Refresh/access token lifecycle (Cookie/Header/Request I/O boundary)
    # ==========================================================================
    def preference_binding_method_class
      case preference_class.name
      when "AppPreference" then AppPreferenceBindingMethod
      when "ComPreference" then ComPreferenceBindingMethod
      when "OrgPreference" then OrgPreferenceBindingMethod
      when "ClientToken" then ClientTokenBindingMethod
      when "OperatorToken" then OperatorTokenBindingMethod
      else
        raise ArgumentError, "Unknown preference class: #{preference_class.name}"
      end
    end

    def preference_dbsc_status_class
      case preference_class.name
      when "AppPreference" then AppPreferenceDbscStatus
      when "ComPreference" then ComPreferenceDbscStatus
      when "OrgPreference" then OrgPreferenceDbscStatus
      when "ClientToken" then ClientTokenDbscStatus
      when "OperatorToken" then OperatorTokenDbscStatus
      else
        raise ArgumentError, "Unknown preference class: #{preference_class.name}"
      end
    end

    def preference_dbsc_payload_for(preference)
      return unless preference

      {
        binding_method: dbsc_binding_method_name(preference),
        status: dbsc_status_name(preference),
        session_id: preference.dbsc_session_id,
        registration_url: preference_dbsc_path,
        verification_url: preference_dbsc_path,
      }
    end

    def preference_dbsc_cookie_expires_at(preference, now: Time.current)
      return unless preference&.binding_method_dbsc?

      times = [now + 10.minutes, preference.expires_at]
      times << preference.revoked_at if preference.respond_to?(:revoked_at)
      times.compact.min
    end

    def issue_preference_dbsc_registration_header_for(preference)
      return unless preference
      return if preference.binding_method_dbsc?

      challenge = issue_preference_dbsc_challenge_for!(preference)
      return if challenge.blank?

      response.set_header(
        Preference::IoKeys::Headers::DBSC_REGISTRATION,
        %((ES256 RS256);path="#{preference_dbsc_path}";challenge="#{challenge}"),
      )
    end

    def issue_preference_dbsc_challenge_for!(preference)
      challenge = SecureRandom.urlsafe_base64(32)
      preference.update!(dbsc_challenge: challenge, dbsc_challenge_issued_at: Time.current)
      challenge
    rescue StandardError
      nil
    end

    def preference_dbsc_path
      case preference_class.name
      when "AppPreference"
        apex_app_edge_v0_dbsc_path if respond_to?(:apex_app_edge_v0_dbsc_path)
      when "OrgPreference"
        apex_org_edge_v0_dbsc_path if respond_to?(:apex_org_edge_v0_dbsc_path)
      when "ComPreference"
        apex_com_edge_v0_dbsc_path if respond_to?(:apex_com_edge_v0_dbsc_path)
      end
    end

    def dbsc_binding_method_name(record)
      return "dbsc" if record.binding_method_dbsc?
      return "legacy" if record.binding_method_legacy?

      "nothing"
    end

    def dbsc_status_name(record)
      return "pending" if record.dbsc_status_pending?
      return "active" if record.dbsc_status_active?
      return "failed" if record.dbsc_status_failed?
      return "revoke" if record.dbsc_status_revoke?

      "nothing"
    end

    def build_preferences_payload(preference)
      association_prefix = preference.class.name.underscore
      option_prefix = preference.class.name.sub("Preference", "")
      option_ids = preference_payload_option_ids(preference, association_prefix)
      consent_state = preference_cookie_consent_state(preference, association_prefix)

      {
        "ver" => Actor::Preference::SCHEMA_VERSION,
        "lx" => option_id_to_language(option_ids[:language], option_prefix) || "ja",
        "ri" => option_id_to_region(option_ids[:region], option_prefix) || "jp",
        "tz" => option_id_to_timezone(option_ids[:timezone], option_prefix) || "Asia/Tokyo",
        "ct" => normalize_colortheme(option_id_to_colortheme(option_ids[:theme], option_prefix)) || "sy",
      }.merge(
        preference_payload_extended_options(option_ids, option_prefix),
        preference_payload_consent(consent_state),
      )
    end

    def preference_payload_option_ids(preference, association_prefix)
      %i(language region timezone theme currency date_format time_format motion density
         items_per_page r18_display_stopper).index_with do |type|
        association_name = "#{association_prefix}_#{type}"
        next unless preference.respond_to?(association_name)

        preference.public_send(association_name)&.option_id
      end
    end

    def preference_payload_extended_options(option_ids, option_prefix)
      {
        "cu" => option_id_to_preference_value(option_ids[:currency], option_prefix, :currency) || "jpy",
        "df" => option_id_to_preference_value(option_ids[:date_format], option_prefix, :date_format) || "iso",
        "tf" => option_id_to_preference_value(option_ids[:time_format], option_prefix, :time_format) || "hour_24",
        "mo" => option_id_to_preference_value(option_ids[:motion], option_prefix, :motion) || "standard",
        "dn" => option_id_to_preference_value(option_ids[:density], option_prefix, :density) || "standard",
        "ipp" => option_id_to_preference_value(option_ids[:items_per_page], option_prefix, :items_per_page) || "20",
        "r18s" => option_id_to_preference_value(
          option_ids[:r18_display_stopper],
          option_prefix,
          :r18_display_stopper,
        ) || "nothing",
      }
    end

    def preference_payload_consent(consent_state)
      {
        "consented" => consent_state[:consented],
        "functional" => consent_state[:functional],
        "performant" => consent_state[:performant],
        "targetable" => consent_state[:targetable],
      }
    end

    def preference_cookie_consent_state(preference, association_prefix)
      cookie_name = "#{association_prefix}_cookie"
      return { consented: false,
               functional: false,
               performant: false,
               targetable: false, } unless preference.respond_to?(cookie_name)

      cookie = preference.public_send(cookie_name)
      return { consented: false, functional: false, performant: false, targetable: false } if cookie.blank?

      {
        consented: !!cookie.consented,
        functional: !!cookie.functional,
        performant: !!cookie.performant,
        targetable: !!cookie.targetable,
      }
    rescue NoMethodError
      { consented: false, functional: false, performant: false, targetable: false }
    end

    def option_id_to_language(option_id, prefix)
      return if option_id.blank?

      option_class = Preference::ClassRegistry.option_class(prefix, :language)
      return "ja" if option_id == option_class::JA
      return "en" if option_class.const_defined?(:EN) && option_id == option_class::EN

      option_id.to_s.downcase
    end

    def option_id_to_region(option_id, prefix)
      return if option_id.blank?

      option_class = Preference::ClassRegistry.option_class(prefix, :region)
      return "jp" if option_id == option_class::JP
      return "us" if option_id == option_class::US

      option_id.to_s.downcase
    end

    def option_id_to_timezone(option_id, prefix)
      return if option_id.blank?

      option_class = Preference::ClassRegistry.option_class(prefix, :timezone)
      return "Asia/Tokyo" if option_id == option_class::ASIA_TOKYO
      return "Etc/UTC" if option_id == option_class::ETC_UTC

      option_id.to_s
    end

    def option_id_to_colortheme(option_id, prefix)
      return if option_id.blank?

      option_class = Preference::ClassRegistry.option_class(prefix, :colortheme)
      return "light" if option_id == option_class::LIGHT
      return "dark" if option_id == option_class::DARK
      return "system" if option_id == option_class::SYSTEM

      option_id.to_s
    end

    def option_id_to_preference_value(option_id, prefix, type)
      return if option_id.blank?

      Preference::ClassRegistry.option_class(prefix, type).find_by(id: option_id)&.name
    end

    def preference_payload_preferences
      Token.extract_preferences(@preference_payload)
    end

    def preference_payload_value(key)
      preference_payload_preferences[key.to_s]
    end

    def preference_payload_public_id
      Token.extract_public_id(@preference_payload)
    end

    def preference_payload_jti
      Token.extract_jti(@preference_payload)
    end

    def clear_preference_refresh_failure!
      @preference_refresh_failed = false
    end

    def preference_refresh_failed?
      @preference_refresh_failed
    end

    def preference_refresh_binding_allowed?(preference)
      return preference_refresh_dbsc_allowed?(preference) if preference.binding_method_dbsc?

      true
    end

    def preference_refresh_dbsc_allowed?(preference)
      unless preference.dbsc_status_active?
        @preference_refresh_binding_reason = "dbsc_not_active"
        return false
      end

      dbsc_cookie = cookies[preference_dbsc_cookie_name].to_s.presence
      if dbsc_cookie.blank?
        @preference_refresh_binding_reason = "missing_bound_cookie"
        return false
      end

      if preference.dbsc_session_id.to_s.blank? || preference.dbsc_session_id != dbsc_cookie
        @preference_refresh_binding_reason = "session_id_mismatch"
        return false
      end

      true
    end

    def handle_preference_refresh_binding_denied(preference, refresh_public_id)
      clear_preference_auth_cookies!
      @preference_refresh_failed = true
      @preference_refresh_binding_denied = true

      Rails.logger.warn(
        {
          message: "Preference refresh denied",
          reason: @preference_refresh_binding_reason || "missing",
          preference_type: preference_class.name,
          preference_public_id: preference&.public_id || refresh_public_id,
          request_id: request.request_id,
        },
      )
    end

    def handle_preference_refresh_failed(preference, refresh_public_id)
      clear_preference_auth_cookies!
      @preference_refresh_failed = true

      Rails.logger.warn(
        {
          message: "Preference refresh failed",
          preference_type: preference_class.name,
          preference_public_id: preference&.public_id || refresh_public_id,
          request_id: request.request_id,
        },
      )
    end

    def render_preference_refresh_error!
      if request.format.json?
        render json: {
          error: I18n.t("sign.token_refresh.errors.invalid_refresh_token"),
          error_code: "invalid_refresh_token",
        }, status: :unauthorized
      else
        head :unauthorized
      end
    end

    def valid_refresh_preference?(preference)
      preference.present? &&
        preference.status_id != preference_status_class::DELETED &&
        (preference.expires_at.nil? || preference.expires_at > Time.current) &&
        !preference.replay? &&
        !preference.revoked?
    end

    def find_preference_by_presented_token
      return nil if @refresh_presented_digest.blank?

      relation = preference_class.where(token_digest: @refresh_presented_digest)
      relation = relation.where(public_id: @refresh_public_id) if @refresh_public_id.present?
      relation.order(:id).last
    end

    def handle_preference_refresh_replay!(preference)
      now = Time.current

      with_preference_connection(:writing) do
        updates = { discarded_at: now }
        updates[:compromised_at] = now if preference.respond_to?(:compromised_at=)
        updates[:revoked_at] = now if preference.respond_to?(:revoked_at=)

        lapses_at_value = preference.discarded_at
        is_infinite = lapses_at_value.respond_to?(:infinite?) && lapses_at_value.infinite?
        already_handled =
          if preference.respond_to?(:compromised_at)
            preference.compromised_at.present?
          else
            !is_infinite && lapses_at_value <= now
          end
        preference.update!(updates) unless already_handled
      end

      clear_preference_auth_cookies!
      @preference_refresh_failed = true

      Rails.logger.info(
        LogEvent.format(
          "preference.token.refresh.replay_detected",
          preference_type: preference_class.name,
          preference_public_id: preference.public_id,
          replaced_by_id: preference.replaced_by_id,
          request_id: request.request_id,
        ),
      )
    end

    # ==========================================================================
    # 6) Cookie/header/session helpers (I/O boundary)
    # ==========================================================================
    def preference_cookie_options(expires_at:, httponly:)
      ::Core::CookieOptions.for(
        surface: ::Core::Surface.current(request),
        request: request,
        expires: expires_at,
        httponly: httponly,
        same_site: :lax,
      )
    end

    def preference_auth_cookie_options(expires_at:)
      preference_cookie_options(expires_at: expires_at, httponly: true)
    end

    def access_token_cookie_name
      if self.class.name.start_with?("Apex::App::Preference")
        Authentication::Base::ACCESS_COOKIE_KEY
      else
        Preference::CookieName.access(surface: preference_cookie_surface)
      end
    end

    def access_token_cookie_names
      [access_token_cookie_name, Preference::CookieName.access].uniq
    end

    def refresh_token_cookie_name
      Preference::CookieName.refresh(surface: preference_cookie_surface)
    end

    def preference_dbsc_cookie_name
      Preference::CookieName.dbsc(surface: preference_cookie_surface)
    end

    def preference_cookie_surface
      case preference_class.name
      when "AppPreference" then :app
      when "ComPreference" then :com
      when "OrgPreference" then :org
      end
    end

    def set_refresh_token_cookie(token, expires_at)
      cookies[refresh_token_cookie_name] = preference_cookie_options(expires_at: expires_at, httponly: true).merge(
        value: token,
      )
    end

    def set_preference_dbsc_cookie!(token, expires_at:)
      cookies[preference_dbsc_cookie_name] = preference_cookie_options(expires_at: expires_at, httponly: true).merge(
        value: token,
      )
    end

    def clear_preference_auth_cookies!
      [access_token_cookie_name, refresh_token_cookie_name,
       preference_dbsc_cookie_name,].uniq.each do |cookie_name|
        cookies.delete(cookie_name, **preference_cookie_deletion_options)
      end
    end

    def preference_cookie_deletion_options
      opts = preference_cookie_options(expires_at: nil, httponly: true)
      opts.delete(:expires)
      opts
    end

    def preference_child_class_suffix(type)
      {
        currency: "Currency",
        date_format: "DateFormat",
        time_format: "TimeFormat",
        motion: "Motion",
        density: "Density",
        items_per_page: "ItemsPerPage",
        r18_display_stopper: "R18DisplayStopper",
      }.fetch(type.to_sym)
    end

    def preference_associations_to_preload
      prefix = preference_class.name.underscore
      [
        "#{prefix}_cookie",
        "#{prefix}_language",
        "#{prefix}_region",
        "#{prefix}_timezone",
        "#{prefix}_colortheme",
        "#{prefix}_currency",
        "#{prefix}_date_format",
        "#{prefix}_time_format",
        "#{prefix}_motion",
        "#{prefix}_density",
        "#{prefix}_items_per_page",
      ].map(&:to_sym)
    end

    # ==========================================================================
    # 7) Child-record lazy helpers
    # ==========================================================================
    def load_or_create_preference_child(child_type, default_attributes = {})
      association_name = "#{preference_prefix_underscore}_#{child_type.to_s.underscore}"
      child = @preferences.public_send(association_name)
      return child if child.present?

      begin
        @preferences.public_send("create_#{association_name}!", default_attributes)
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        @preferences.reload
        @preferences.public_send(association_name)
      end
    end
  end
end
