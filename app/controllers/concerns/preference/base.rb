# typed: false
# frozen_string_literal: true

require "jwt"
require "base64"
require "json"
require "openssl"
require "sha3"
require "concurrent"

module Preference
  # ==========================================================================
  # TOC (approximate)
  # 1) JWT configuration & token primitives ........................... L8-L168
  # 2) Preference request entrypoints (I/O boundary) .................. L170-L240
  # 3) Preference option/domain mapping ............................... L240-L406
  # 4) Audit + preference domain updates .............................. L409-L530
  # 5) Refresh/access token lifecycle (I/O + domain) ................. L533-L895
  # 6) Cookie/header/session helpers (I/O boundary) ................... L897-L985
  # 7) Child-record lazy helpers ...................................... L985-L1005
  # ==========================================================================

  # ==========================================================================
  # 1) JWT configuration & token primitives
  # ==========================================================================
  module JwtConfiguration
    def self.active_kid
      ENV.fetch("PREFERENCE_JWT_ACTIVE_KID", "default")
    end

    def self.leeway_seconds
      Integer(ENV.fetch("PREFERENCE_JWT_LEEWAY_SECONDS", "30").to_s, 10)
    end

    def self.issuer
      ENV.fetch("PREFERENCE_JWT_ISSUER", "jit-preference")
    end

    def self.audiences
      raw = ENV["PREFERENCE_JWT_AUDIENCES"].to_s
      audiences = raw.split(",").map(&:strip)
      audiences.reject!(&:empty?)
      audiences
    end

    # Returns audiences scoped to the TLD of the given host.
    # e.g., host "id.umaxica.app" results in only audiences ending with ".app" or equal to an ".app" apex.
    # In development, "localhost" is always included as an additional audience.
    def self.audience_for(host)
      return audiences if host.blank?

      all = audiences
      return all if all.empty?

      # Extract the TLD from the host (e.g., "id.umaxica.app" results in "app", "localhost" results in "localhost")
      host_parts = host.split(".")
      host_tld = host_parts.last

      matched = all.select { |aud| aud.split(".").last == host_tld }

      # In non-production, keep "localhost" if present in the configured audiences
      if !Rails.env.production? && (matched.present? || host_tld == "localhost")
        localhost_aud = all.find { |aud| aud == "localhost" || aud.end_with?(".localhost") }
        matched << localhost_aud if localhost_aud && matched.exclude?(localhost_aud)
      end

      matched.presence || [host]
    end

    def self.host_scope_for(host)
      return host if host.blank?

      matching_audience =
        audience_for(host).sort_by { |aud| -aud.to_s.length }.find do |aud|
          next false if aud.blank?

          host == aud || host.end_with?(".#{aud}")
        end

      matching_audience.presence || host
    end

    def self.private_key_for_active
      private_key_for(active_kid)
    end

    def self.private_key_for(kid)
      keyset = parse_keyset(Rails.app.creds.option(:PREFERENCE_JWT_PRIVATE_KEYSET))
      decode_key(keyset[kid])
    end

    def self.public_key_for(kid)
      keyset = parse_keyset(Rails.app.creds.option(:PREFERENCE_JWT_PUBLIC_KEYSET))
      decode_key(keyset[kid])
    end

    def self.private_key
      private_key_for(active_kid)
    end

    def self.public_key
      public_key_for(active_kid)
    end

    def self.parse_header(token)
      _payload, header = JWT.decode(token, nil, false)
      header || {}
    rescue JWT::DecodeError
      {}
    end

    def self.parse_keyset(raw)
      return {} if raw.blank?

      parsed = JSON.parse(raw)
      return parsed if parsed.is_a?(Hash)

      {}
    rescue JSON::ParserError
      {}
    end

    def self.decode_key(base64_der)
      return nil if base64_der.blank?

      OpenSSL::PKey::EC.new(Base64.decode64(base64_der))
    rescue OpenSSL::PKey::PKeyError
      nil
    end
    private_class_method :parse_keyset, :decode_key
  end

  class Token
    JWT_ALGORITHM = "ES384"
    ACCESS_TOKEN_TTL = 7.days
    TOKEN_TYPE = "preference-access-token"

    class << self
      def encode(preferences, host:, preference_type:, public_id:, jti:)
        return nil unless valid_encode_params?(preferences, host, preference_type, public_id, jti)

        payload = build_payload(preferences, host, preference_type, public_id, jti)
        JWT.encode(
          payload,
          JwtConfiguration.private_key_for_active,
          JWT_ALGORITHM,
          { kid: JwtConfiguration.active_kid, typ: TOKEN_TYPE },
        )
      rescue StandardError => e
        Rails.logger.error("PreferenceToken.encode failed: #{e.message}")
        nil
      end

      def decode(token, host:)
        return nil if token.blank? || host.blank?

        header = JwtConfiguration.parse_header(token)
        unless valid_header?(header)
          report_invalid_header(host: host, header: header)
          return nil
        end

        public_key = JwtConfiguration.public_key_for(header["kid"])
        if public_key.nil?
          Jit::Security::Jwt::AnomalyReporter.report_preference(
            host: host,
            header: header,
            reason: "UNKNOWN_KID",
          )
          return nil
        end

        payload, = JWT.decode(token, public_key, true, decode_options)
        validated_payload = validate_payload(payload, host)
        unless validated_payload
          report_invalid_payload(host: host, header: header, payload: payload)
          return nil
        end

        validated_payload
      rescue JWT::ExpiredSignature
        Jit::Security::Jwt::AnomalyReporter.report_preference(
          host: host,
          header: header,
          reason: "EXPIRED",
        )
        Rails.logger.debug("PreferenceToken.decode failed: token expired")
        nil
      rescue JWT::InvalidIssuerError, JWT::InvalidIatError, JWT::ImmatureSignature => e
        report_claim_error(host: host, header: header, error: e)
        Rails.logger.debug { "PreferenceToken.decode invalid claims: #{e.class}: #{e.message}" }
        nil
      rescue JWT::DecodeError, JWT::VerificationError => e
        report_decode_error(host: host, header: header, error: e)
        Rails.logger.debug { "PreferenceToken.decode invalid token: #{e.message}" }
        nil
      rescue StandardError => e
        Rails.logger.error("PreferenceToken.decode failed: #{e.message}")
        nil
      end

      def extract_preferences(payload)
        return {} unless payload.is_a?(Hash)

        payload["preferences"] || {}
      end

      def extract_public_id(payload)
        payload&.dig("public_id")
      end

      def extract_preference_type(payload)
        payload&.dig("preference_type")
      end

      def extract_jti(payload)
        payload&.dig("jti")
      end

      private

      def valid_encode_params?(preferences, host, preference_type, public_id, jti)
        [preferences, host, preference_type, public_id, jti].all?(&:present?)
      end

      def build_payload(preferences, host, preference_type, public_id, jti)
        now = Time.current.to_i
        {
          preferences: preferences,
          host: JwtConfiguration.host_scope_for(host),
          preference_type: preference_type,
          public_id: public_id,
          jti: jti,
          typ: TOKEN_TYPE,
          iss: JwtConfiguration.issuer,
          aud: JwtConfiguration.audience_for(host),
          iat: now,
          exp: now + Integer(ACCESS_TOKEN_TTL.to_s, 10),
        }
      end

      def decode_options
        {
          algorithms: [JWT_ALGORITHM],
          required_claims: %w(iss aud typ exp public_id jti preference_type),
          leeway: JwtConfiguration.leeway_seconds,
          verify_iss: true,
          iss: JwtConfiguration.issuer,
          verify_aud: false,
          verify_iat: true,
          verify_exp: true,
        }
      end

      def validate_payload(payload, host)
        return nil unless payload.is_a?(Hash)
        return nil unless payload["typ"] == TOKEN_TYPE
        return nil unless host_matches?(payload["host"], host)
        return nil unless audience_matches?(payload["aud"], host)

        payload
      end

      def valid_header?(header)
        return false if header.blank?
        return false unless header["alg"] == JWT_ALGORITHM
        return false if header["kid"].blank?

        header["typ"] == TOKEN_TYPE
      end

      def report_invalid_header(host:, header:)
        reason =
          if header.blank? || header["alg"].blank?
            "MALFORMED_TOKEN"
          elsif header["kid"].blank?
            "MISSING_KID"
          elsif header["alg"] == "none"
            "ALG_NONE"
          elsif header["alg"] != JWT_ALGORITHM
            "ALG_MISMATCH"
          elsif header["typ"].blank?
            "MISSING_TYP"
          else
            "TYP_MISMATCH"
          end

        Jit::Security::Jwt::AnomalyReporter.report_preference(host: host, header: header, reason: reason)
      end

      def report_invalid_payload(host:, header:, payload:)
        reason =
          if payload["typ"] != TOKEN_TYPE
            "TYP_MISMATCH"
          elsif payload["host"].blank? || !host_matches?(payload["host"], host)
            "HOST_MISMATCH"
          elsif !audience_matches?(payload["aud"], host)
            "AUD_MISMATCH"
          else
            "OTHER"
          end

        Jit::Security::Jwt::AnomalyReporter.report_preference(
          host: host,
          header: header,
          payload: payload,
          reason: reason,
        )
      end

      def report_claim_error(host:, header:, error:)
        reason =
          case error
          when JWT::InvalidIssuerError then "ISS_MISMATCH"
          when JWT::InvalidIatError then "IAT_INVALID"
          when JWT::ImmatureSignature then "IMMATURE"
          else "OTHER"
          end

        Jit::Security::Jwt::AnomalyReporter.report_preference(
          host: host,
          header: header,
          reason: reason,
          error: error,
        )
      end

      def report_decode_error(host:, header:, error:)
        reason =
          if error.message.to_s.include?("Missing required claim")
            Jit::Security::Jwt::AnomalyReporter.reason_for_missing_claim(error.message)
          elsif error.message.to_s.include?("Signature verification failed")
            "SIGNATURE_INVALID"
          elsif error.message.to_s.match?(/Not enough or too many segments|Invalid segment encoding/)
            "MALFORMED_TOKEN"
          else
            "DECODE_ERROR"
          end

        Jit::Security::Jwt::AnomalyReporter.report_preference(
          host: host,
          header: header,
          reason: reason,
          error: error,
        )
      end

      def host_matches?(host_claim, host)
        return false if host_claim.blank?

        host == host_claim || host.end_with?(".#{host_claim}")
      end

      def audience_matches?(aud_claim, host)
        normalize_audiences(aud_claim).any? do |aud|
          host == aud || host.end_with?(".#{aud}")
        end
      end

      def normalize_audiences(aud_claim)
        case aud_claim
        when Array then aud_claim
        when String then [aud_claim]
        else []
        end
      end
    end
  end

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

    PREFERENCE_AUDIT_EVENT_ID_MAP = {
      "AppPreferenceChronicleEvent" => {
        "CREATE_NEW_PREFERENCE_TOKEN" => AppPreferenceChronicleEvent::CREATE_NEW_PREFERENCE_TOKEN,
        "REFRESH_TOKEN_ROTATED" => AppPreferenceChronicleEvent::REFRESH_TOKEN_ROTATED,
        "UPDATE_PREFERENCE_COOKIE" => AppPreferenceChronicleEvent::UPDATE_PREFERENCE_COOKIE,
        "UPDATE_PREFERENCE_LANGUAGE" => AppPreferenceChronicleEvent::UPDATE_PREFERENCE_LANGUAGE,
        "UPDATE_PREFERENCE_TIMEZONE" => AppPreferenceChronicleEvent::UPDATE_PREFERENCE_TIMEZONE,
        "RESET_BY_USER_DECISION" => AppPreferenceChronicleEvent::RESET_BY_USER_DECISION,
        "UPDATE_PREFERENCE_REGION" => AppPreferenceChronicleEvent::UPDATE_PREFERENCE_REGION,
        "UPDATE_PREFERENCE_COLORTHEME" => AppPreferenceChronicleEvent::UPDATE_PREFERENCE_THEME,
        "UPDATE_PREFERENCE_CURRENCY" => AppPreferenceChronicleEvent::UPDATE_PREFERENCE_CURRENCY,
        "UPDATE_PREFERENCE_DATE_FORMAT" => AppPreferenceChronicleEvent::UPDATE_PREFERENCE_DATE_FORMAT,
        "UPDATE_PREFERENCE_TIME_FORMAT" => AppPreferenceChronicleEvent::UPDATE_PREFERENCE_TIME_FORMAT,
        "UPDATE_PREFERENCE_MOTION" => AppPreferenceChronicleEvent::UPDATE_PREFERENCE_MOTION,
        "UPDATE_PREFERENCE_DENSITY" => AppPreferenceChronicleEvent::UPDATE_PREFERENCE_DENSITY,
        "UPDATE_PREFERENCE_ITEMS_PER_PAGE" => AppPreferenceChronicleEvent::UPDATE_PREFERENCE_ITEMS_PER_PAGE,
      }.freeze,
      "ComPreferenceChronicleEvent" => {
        "CREATE_NEW_PREFERENCE_TOKEN" => ComPreferenceChronicleEvent::CREATE_NEW_PREFERENCE_TOKEN,
        "REFRESH_TOKEN_ROTATED" => ComPreferenceChronicleEvent::REFRESH_TOKEN_ROTATED,
        "UPDATE_PREFERENCE_COOKIE" => ComPreferenceChronicleEvent::UPDATE_PREFERENCE_COOKIE,
        "UPDATE_PREFERENCE_LANGUAGE" => ComPreferenceChronicleEvent::UPDATE_PREFERENCE_LANGUAGE,
        "UPDATE_PREFERENCE_TIMEZONE" => ComPreferenceChronicleEvent::UPDATE_PREFERENCE_TIMEZONE,
        "RESET_BY_USER_DECISION" => ComPreferenceChronicleEvent::RESET_BY_USER_DECISION,
        "UPDATE_PREFERENCE_REGION" => ComPreferenceChronicleEvent::UPDATE_PREFERENCE_REGION,
        "UPDATE_PREFERENCE_COLORTHEME" => ComPreferenceChronicleEvent::UPDATE_PREFERENCE_THEME,
        "UPDATE_PREFERENCE_CURRENCY" => ComPreferenceChronicleEvent::UPDATE_PREFERENCE_CURRENCY,
        "UPDATE_PREFERENCE_DATE_FORMAT" => ComPreferenceChronicleEvent::UPDATE_PREFERENCE_DATE_FORMAT,
        "UPDATE_PREFERENCE_TIME_FORMAT" => ComPreferenceChronicleEvent::UPDATE_PREFERENCE_TIME_FORMAT,
        "UPDATE_PREFERENCE_MOTION" => ComPreferenceChronicleEvent::UPDATE_PREFERENCE_MOTION,
        "UPDATE_PREFERENCE_DENSITY" => ComPreferenceChronicleEvent::UPDATE_PREFERENCE_DENSITY,
        "UPDATE_PREFERENCE_ITEMS_PER_PAGE" => ComPreferenceChronicleEvent::UPDATE_PREFERENCE_ITEMS_PER_PAGE,
      }.freeze,
      "OrgPreferenceChronicleEvent" => {
        "CREATE_NEW_PREFERENCE_TOKEN" => OrgPreferenceChronicleEvent::CREATE_NEW_PREFERENCE_TOKEN,
        "REFRESH_TOKEN_ROTATED" => OrgPreferenceChronicleEvent::REFRESH_TOKEN_ROTATED,
        "UPDATE_PREFERENCE_COOKIE" => OrgPreferenceChronicleEvent::UPDATE_PREFERENCE_COOKIE,
        "UPDATE_PREFERENCE_LANGUAGE" => OrgPreferenceChronicleEvent::UPDATE_PREFERENCE_LANGUAGE,
        "UPDATE_PREFERENCE_TIMEZONE" => OrgPreferenceChronicleEvent::UPDATE_PREFERENCE_TIMEZONE,
        "RESET_BY_USER_DECISION" => OrgPreferenceChronicleEvent::RESET_BY_USER_DECISION,
        "UPDATE_PREFERENCE_REGION" => OrgPreferenceChronicleEvent::UPDATE_PREFERENCE_REGION,
        "UPDATE_PREFERENCE_COLORTHEME" => OrgPreferenceChronicleEvent::UPDATE_PREFERENCE_THEME,
        "UPDATE_PREFERENCE_CURRENCY" => OrgPreferenceChronicleEvent::UPDATE_PREFERENCE_CURRENCY,
        "UPDATE_PREFERENCE_DATE_FORMAT" => OrgPreferenceChronicleEvent::UPDATE_PREFERENCE_DATE_FORMAT,
        "UPDATE_PREFERENCE_TIME_FORMAT" => OrgPreferenceChronicleEvent::UPDATE_PREFERENCE_TIME_FORMAT,
        "UPDATE_PREFERENCE_MOTION" => OrgPreferenceChronicleEvent::UPDATE_PREFERENCE_MOTION,
        "UPDATE_PREFERENCE_DENSITY" => OrgPreferenceChronicleEvent::UPDATE_PREFERENCE_DENSITY,
        "UPDATE_PREFERENCE_ITEMS_PER_PAGE" => OrgPreferenceChronicleEvent::UPDATE_PREFERENCE_ITEMS_PER_PAGE,
      }.freeze,
    }.freeze

    def show_cookie_banner?
      false
    end

    private

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
      theme = normalize_colortheme(params[Preference::IoKeys::Params::CT].presence)
      theme ||= normalize_colortheme(actor_preference_theme)
      theme ||= normalize_colortheme(preference_payload_value("ct"))
      theme ||= normalize_colortheme(cookies[THEME_COOKIE_KEY])
      theme ||= preference_record_theme
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
      return event_id if event_id.is_a?(Integer)

      event_map = PREFERENCE_AUDIT_EVENT_ID_MAP[preference_audit_event_class.name]
      return event_id unless event_map

      event_map.fetch(event_id.to_s, event_id)
    end

    def ensure_preferences_record
      load_preference_record_from_refresh_token!(create_if_missing: true)
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
         items_per_page).index_with do |type|
        preference.public_send("#{association_prefix}_#{type}")&.option_id
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
      cookie = preference.public_send("#{association_prefix}_cookie")
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
      @preference_refresh_device_denied = false
    end

    def preference_refresh_failed?
      @preference_refresh_failed
    end

    def extract_preference_refresh_device_id
      cookie_device_id = read_preference_device_id_cookie

      if cookie_device_id.blank?
        @preference_refresh_device_reason = "missing"
        return nil
      end

      cookie_device_id
    end

    def preference_refresh_binding_allowed?(preference)
      return preference_refresh_dbsc_allowed?(preference) if preference.binding_method_dbsc?

      refresh_device_id = extract_preference_refresh_device_id
      if refresh_device_id.blank?
        @preference_refresh_device_reason = "missing"
        return false
      end

      # Compare using SHA3-384 digest for security
      # Cookie contains plaintext device_id, DB stores digest
      presented_digest = digest_device_id(refresh_device_id)
      if preference.device_id_digest.blank? || !secure_compare?(preference.device_id_digest, presented_digest)
        @preference_refresh_device_reason = "mismatch"
        return false
      end

      true
    end

    def preference_refresh_dbsc_allowed?(preference)
      unless preference.dbsc_status_active?
        @preference_refresh_device_reason = "dbsc_not_active"
        return false
      end

      dbsc_cookie = cookies[preference_dbsc_cookie_name].to_s.presence
      if dbsc_cookie.blank?
        @preference_refresh_device_reason = "missing_bound_cookie"
        return false
      end

      if preference.dbsc_session_id.to_s.blank? || preference.dbsc_session_id != dbsc_cookie
        @preference_refresh_device_reason = "session_id_mismatch"
        return false
      end

      true
    end

    def handle_preference_refresh_device_denied(preference, refresh_public_id)
      clear_preference_auth_cookies!
      @preference_refresh_failed = true
      @preference_refresh_device_denied = true

      Rails.logger.warn(
        {
          message: "Preference refresh denied",
          reason: @preference_refresh_device_reason || "missing",
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

    def preference_device_id_cookie_name
      Preference::CookieName.device(refresh_cookie_key: refresh_token_cookie_name)
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

    def set_preference_device_id_cookie!(device_id, expires_at:)
      cookies[preference_device_id_cookie_name] = preference_cookie_options(
        expires_at: expires_at,
        httponly: true,
      ).merge(
        value: device_id,
      )
    end

    def read_preference_device_id_cookie
      cookies[preference_device_id_cookie_name].to_s.presence
    end

    def clear_preference_auth_cookies!
      [access_token_cookie_name, refresh_token_cookie_name,
       preference_device_id_cookie_name, preference_dbsc_cookie_name,].uniq.each do |cookie_name|
        cookies.delete(cookie_name, **preference_cookie_deletion_options)
      end
    end

    def preference_cookie_deletion_options
      opts = preference_cookie_options(expires_at: nil, httponly: true)
      opts.delete(:expires)
      opts
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
