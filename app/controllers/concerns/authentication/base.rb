# typed: false
# frozen_string_literal: true

require "jwt"

module Authentication
  module Base
    extend ActiveSupport::Concern
    include Common::Redirect
    include RefreshTokenShared

    # ==========================================================================
    # TOC (approximate)
    # 1) JWT & Token primitives ....................................... L40-L210
    # 2) Request guards (public API, I/O boundary) .................... L215-L275
    # 3) Redirect/bulletin session flows (I/O boundary) ............... L277-L462
    # 4) Session auth lifecycle (public API, I/O boundary) ............ L464-L775
    # 5) Abstract contract & policy DSL ............................... L778-L907
    # 6) Private request/cookie/token I/O ............................. L909-L1505
    # 7) Policy/domain decisions ...................................... L1514-L1869
    # 8) MFA/session helper decisions ................................. L1873-L1966
    # ==========================================================================

    # ==========================================================================
    # 1) JWT & Token primitives
    # ==========================================================================

    # --- Policy errors ---
    class MissingPolicyError < StandardError; end

    class InvalidPolicyError < StandardError; end

    class SkipNotAllowedError < StandardError; end

    VALID_POLICIES = %i(
      public_strict
      auth_required
      guest_only
    ).freeze

    ACCESS_POLICY_RULES = Concurrent::Map.new

    # Cookie keys - environment-dependent naming
    # Production: "__Host-" prefix for host-only secure cookies
    # Dev/Test: no prefix (String, not Symbol)
    ACCESS_COOKIE_KEY = Auth::CookieName.access
    REFRESH_COOKIE_KEY = Auth::CookieName.refresh
    DBSC_COOKIE_KEY = Auth::CookieName.dbsc
    DEVICE_COOKIE_KEY = Auth::CookieName.device(refresh_cookie_key: REFRESH_COOKIE_KEY)

    # Token TTLs
    ACCESS_TOKEN_TTL = Integer(ENV.fetch("AUTH_ACCESS_TOKEN_TTL", 1.hour.to_i.to_s), 10).seconds
    REFRESH_TOKEN_TTL = 30.days
    DBSC_COOKIE_TTL = 10.minutes
    RESTRICTED_SESSION_TTL = 15.minutes
    LOGIN_COOLDOWN = 30.seconds
    SESSION_LIMIT_HARD_REJECT_MESSAGE = I18n.t(
      "errors.messages.session_limit_exceeded",
      default: "Session limit exceeded",
    )
    LOGIN_COOLDOWN_MESSAGE = I18n.t("errors.messages.login_cooldown", default: "Please wait before logging in again")

    class LoginCooldownError < StandardError; end

    # Prevents rapid re-login by enforcing a 30-second cooldown between sessions.
    # Disabled in test env by default because fixture-loaded tokens have created_at
    # near Time.current, which would trip the cooldown on every login in test.
    # Enable explicitly in tests that need to verify cooldown behavior.
    LOGIN_COOLDOWN_ENABLED = Concurrent::AtomicReference.new(!Rails.env.test?)

    class << self
      def login_cooldown_enabled
        LOGIN_COOLDOWN_ENABLED.get
      end

      def login_cooldown_enabled=(value)
        LOGIN_COOLDOWN_ENABLED.set(value)
      end
    end

    AUDIT_EVENTS = {
      logged_in: "LOGGED_IN",
      logged_out: "LOGGED_OUT",
      login_failed: "LOGIN_FAILED",
      token_refreshed: "TOKEN_REFRESHED",
    }.freeze

    VALID_ACTOR_TYPES = %w(user staff).freeze

    module JwtConfiguration
      VALID_RESOURCE_TYPES = %w(user staff customer).freeze

      def self.leeway_seconds
        Integer(ENV.fetch("AUTH_JWT_LEEWAY_SECONDS", "30"), 10)
      end

      def self.issuer(resource_type = nil)
        base = ENV.fetch("AUTH_JWT_ISSUER", "umaxica-auth")
        normalized_resource_type = normalize_resource_type(resource_type)
        return base if normalized_resource_type.nil?

        "#{base}:#{normalized_resource_type}"
      end

      def self.audiences(resource_type = nil)
        normalized_resource_type = normalize_resource_type(resource_type)
        resource_key = normalized_resource_type&.upcase
        raw =
          if resource_key.present?
            ENV["AUTH_JWT_#{resource_key}_AUDIENCES"].presence || ENV["AUTH_JWT_AUDIENCES"].to_s
          else
            ENV["AUTH_JWT_AUDIENCES"].to_s
          end
        audiences = raw.split(",").map(&:strip)
        audiences.reject!(&:empty?)
        audiences.presence || ["umaxica-api"]
      end

      def self.token_type(resource_type)
        normalized_resource_type = normalize_resource_type(resource_type)
        raise ArgumentError, "unsupported auth resource type: #{resource_type.inspect}" if normalized_resource_type.nil?

        "auth-access-token;#{normalized_resource_type}"
      end

      def self.private_key
        Jit::Security::Jwt::Keyring.private_key_for_active
      end

      def self.public_key
        Jit::Security::Jwt::Keyring.public_key_for_active
      end

      def self.normalize_resource_type(resource_type)
        return nil if resource_type.blank?

        normalized = resource_type.to_s
        return normalized if VALID_RESOURCE_TYPES.include?(normalized)

        nil
      end
      private_class_method :normalize_resource_type
    end

    class Token
      JWT_ALGORITHM = "ES384"

      class << self
        def encode(resource, host:, session_public_id: nil, session_id: nil, resource_type: nil, dpop_jkt: nil,
                   expires_at: nil, preferences: nil, acr: nil, amr: nil)
          Auth::TokenService.encode(
            resource, host: host, session_public_id: session_public_id, session_id: session_id,
                      resource_type: resource_type, dpop_jkt: dpop_jkt,
                      expires_at: expires_at, preferences: preferences, acr: acr, amr: amr,
          )
        end

        def decode(token, host:, resource_type: nil, issuer: nil, audiences: nil)
          Auth::TokenService.decode(
            token, host: host, resource_type: resource_type, issuer: issuer,
                   audiences: audiences,
          )
        end

        def extract_subject(payload)
          Auth::TokenService.extract_subject(payload)
        end

        def extract_act(payload)
          Auth::TokenService.extract_act(payload)
        end

        def extract_type(payload)
          Auth::TokenService.extract_type(payload)
        end

        def validate_actor_claim!(payload, expected_act)
          Auth::TokenService.validate_actor_claim!(payload, expected_act)
        end

        def extract_session_id(payload)
          Auth::TokenService.extract_session_id(payload)
        end

        def extract_jti(payload)
          Auth::TokenService.extract_jti(payload)
        end
      end
    end

    def logged_in?
      current_resource.present?
    end

    # ======================================================================
    # 2) Request guards (public API, Request I/O boundary)
    # - Reads request format and writes HTTP response
    # ======================================================================

    # Ensures user is not already logged in
    # Renders bad_request with message if user is logged in
    # Used for authentication endpoints (login)
    #
    # @param message_key [String] Optional translation key for the error message
    # @return [nil] Returns nil if user is logged in (stops filter chain)
    def ensure_not_logged_in(message_key: nil)
      return unless logged_in?

      message = message_key ? t(message_key) : I18n.t("errors.messages.not_authorized")
      render plain: message, status: :unauthorized
      nil
    end

    # Ensures user is not already logged in (registration variant)
    # Redirects to root with alert message if user is logged in
    # Used for registration endpoints
    #
    # @param redirect_path [String] Path to redirect to (default: "/")
    # @param message_key [String] Optional translation key for the alert message
    def ensure_not_logged_in_for_registration(redirect_path: "/", message_key: nil)
      return unless logged_in?

      message = message_key ? t(message_key) : I18n.t("errors.messages.not_authorized")

      if request.format.json?
        render plain: message, status: :unauthorized
      else
        redirect_to(redirect_path, alert: message)
      end
    end

    # Checks if user is logged in and renders error if so (inline variant)
    # Returns true if user is logged in, false otherwise
    # Useful for inline checks in actions
    #
    # @param message_key [String] Translation key for the error message
    # @return [Boolean] true if user is logged in, false otherwise
    def reject_if_logged_in(message_key)
      if logged_in?
        render plain: t(message_key), status: :bad_request
        true
      else
        false
      end
    end

    # Reject if user/staff is already logged in with 401 Unauthorized
    def reject_logged_in_session
      return unless logged_in?

      render plain: I18n.t("errors.messages.not_authorized"), status: :unauthorized
    end

    # ======================================================================
    # 3) Redirect/bulletin session flows (Session/params I/O boundary)
    # - Reads/writes params, flash, session
    # ======================================================================

    # Default session key for storing redirect parameter
    DEFAULT_RD_SESSION_KEY = Auth::IoKeys::Session::DEFAULT_RD
    BULLETIN_SESSION_KEY = Auth::IoKeys::Session::BULLETIN
    BULLETIN_TIMEOUT = 2.hours

    # Preserves the redirect parameter in session and returns it for immediate use
    #
    # @param session_key [Symbol] The session key to store rd parameter in
    # @return [String, nil] The rd parameter value if present
    def preserve_redirect_parameter(session_key = DEFAULT_RD_SESSION_KEY)
      return if params[Auth::IoKeys::Params::RD].blank?

      session[session_key] = params[Auth::IoKeys::Params::RD]
      params[Auth::IoKeys::Params::RD]
    end

    # Retrieves and clears the redirect parameter from session
    # Falls back to params[:rd] if session is empty
    #
    # @param session_key [Symbol] The session key to retrieve from
    # @return [String, nil] The rd parameter value
    def retrieve_redirect_parameter(session_key = DEFAULT_RD_SESSION_KEY)
      rd_param = params[Auth::IoKeys::Params::RD].presence || session[session_key]
      session[session_key] = nil
      rd_param
    end

    # Retrieves redirect parameter without clearing session
    #
    # @param session_key [Symbol] The session key to retrieve from
    # @return [String, nil] The rd parameter value
    def peek_redirect_parameter(session_key = DEFAULT_RD_SESSION_KEY)
      params[Auth::IoKeys::Params::RD].presence || session[session_key]
    end

    # Builds redirect params hash with optional rd parameter
    # Automatically includes rd from params or session if present
    #
    # @param message_key [Symbol] Either :notice or :alert
    # @param message_value [String] The message text or translation key result
    # @param session_key [Symbol] The session key to check for rd parameter
    # @return [Hash] Redirect params hash
    def build_redirect_params(message_key, message_value, session_key = DEFAULT_RD_SESSION_KEY)
      redirect_params = { message_key => message_value }
      rd_value = peek_redirect_parameter(session_key)
      redirect_params[Auth::IoKeys::Params::RD] = rd_value if rd_value.present?
      redirect_params
    end

    # Builds redirect params hash with notice message
    #
    # @param message_value [String] The notice message
    # @param session_key [Symbol] The session key to check for rd parameter
    # @return [Hash] Redirect params with notice
    def build_notice_params(message_value, session_key = DEFAULT_RD_SESSION_KEY)
      build_redirect_params(:notice, message_value, session_key)
    end

    # Builds redirect params hash with alert message
    #
    # @param message_value [String] The alert message
    # @param session_key [Symbol] The session key to check for rd parameter
    # @return [Hash] Redirect params with alert
    def build_alert_params(message_value, session_key = DEFAULT_RD_SESSION_KEY)
      build_redirect_params(:alert, message_value, session_key)
    end

    # Performs redirect with rd parameter handling
    # Either redirects to encoded rd URL or falls back to default path
    #
    # @param default_path [String] Default path if no rd parameter
    # @param message_key [Symbol] Either :notice or :alert
    # @param message_value [String] Flash message value
    # @param session_key [Symbol] The session key for rd parameter
    def redirect_with_rd_handling(default_path, message_key, message_value,
                                  session_key = DEFAULT_RD_SESSION_KEY)
      rd_param = retrieve_redirect_parameter(session_key)

      if rd_param.present?
        flash[message_key] = message_value
        jump_to_generated_url(rd_param, fallback: default_path)
      else
        redirect_to(default_path, message_key => message_value)
      end
    end

    # Performs redirect with notice message and rd handling
    #
    # @param default_path [String] Default path if no rd parameter
    # @param message_value [String] Notice message value
    # @param session_key [Symbol] The session key for rd parameter
    def redirect_with_notice(default_path, message_value, session_key = DEFAULT_RD_SESSION_KEY)
      redirect_with_rd_handling(default_path, :notice, message_value, session_key)
    end

    # Performs redirect with alert message and rd handling
    #
    # @param default_path [String] Default path if no rd parameter
    # @param message_value [String] Alert message value
    # @param session_key [Symbol] The session key for rd parameter
    def redirect_with_alert(default_path, message_value, session_key = DEFAULT_RD_SESSION_KEY)
      redirect_with_rd_handling(default_path, :alert, message_value, session_key)
    end

    # Adds rd parameter to existing redirect params if present
    # Modifies the hash in place
    #
    # @param redirect_params [Hash] The redirect params hash to modify
    # @param session_key [Symbol] The session key to check for rd parameter
    # @return [Hash] The modified redirect_params hash
    def add_rd_to_params!(redirect_params, session_key = DEFAULT_RD_SESSION_KEY)
      rd_value = peek_redirect_parameter(session_key)
      redirect_params[Auth::IoKeys::Params::RD] = rd_value if rd_value.present?
      redirect_params
    end

    # ======================================================================
    # 3-1) Bulletin flow (Session/header I/O boundary + test hook)
    # ======================================================================

    def issue_bulletin!(kind: "mock", state: "new", payload: {})
      bulletin = find_unread_bulletin
      return false unless bulletin

      session[BULLETIN_SESSION_KEY] = {
        "issued_at" => Time.current.to_i,
        "kind" => kind.to_s,
        "state" => state.to_s,
        "bulletin_id" => bulletin.id,
      }.merge(payload.stringify_keys)
      true
    end

    # Injects bulletin state from a test header (X-TEST-BULLETIN).
    # Used as a before_action in bulletin controllers to seed session
    # state for integration tests that cannot set session directly.
    def maybe_inject_test_bulletin!
      return unless Rails.env.test?

      raw = request.headers[Auth::IoKeys::Headers::TEST_BULLETIN]
      return if raw.blank?
      return if session[BULLETIN_SESSION_KEY].present?

      session[BULLETIN_SESSION_KEY] = JSON.parse(raw)
    end

    def bulletin_state
      raw = session[BULLETIN_SESSION_KEY]
      return nil unless raw.is_a?(Hash)

      raw.with_indifferent_access
    end

    def bulletin_active?
      bulletin_state.present? && !bulletin_expired?
    end

    def bulletin_expired?
      data = bulletin_state
      return true if data.blank?

      issued_at = epoch_seconds(data[:issued_at])
      return true if issued_at <= 0

      Time.current.to_i >= issued_at + BULLETIN_TIMEOUT.to_i
    end

    def refresh_bulletin_dimension!(state: "updated")
      data = bulletin_state
      return unless data

      session[BULLETIN_SESSION_KEY] = data.merge(
        "issued_at" => Time.current.to_i,
        "state" => state.to_s,
      )
    end

    def consume_bulletin!
      mark_current_bulletin_as_read!
      session.delete(BULLETIN_SESSION_KEY)
    end

    def current_bulletin
      data = bulletin_state
      return nil unless data
      return nil unless data[:bulletin_id]

      bulletin_association_for_resource&.find_by(id: data[:bulletin_id])
    end

    def safe_redirect_to_rd_or_default!(rd_param, default_path:)
      if rd_param.present?
        jump_to_generated_url(rd_param, fallback: default_path)
      else
        redirect_to(default_path)
      end
    end

    # ======================================================================
    # 4) Session auth lifecycle (public API, Cookie/session/request I/O boundary)
    # ======================================================================

    # Loads authentication session data and validates expiry
    # Returns the found record or handles redirect on expiry
    #
    # @param session_key [Symbol, String] The session key to load from
    # @param model_class [Class] The model class to load
    # @param redirect_path [String, Symbol] Where to redirect on session expiry
    # @param redirect_message [String] The translation key for expiry message
    # @param block [Proc] Optional block for additional validation
    # @return [ActiveRecord::Base, nil] The loaded record or nil
    def load_authentication_session(session_key, model_class, redirect_path, redirect_message)
      record = nil

      if session[session_key].present?
        record = model_class.find_by(id: session[session_key])

        # If block provided, use it for validation; otherwise just check presence
        is_valid =
          if block_given?
            yield(record)
          else
            record.present?
          end

        return record if is_valid

        # Session expired or invalid
        handle_session_expiry(redirect_path, redirect_message)
        nil
      else
        # No session data
        handle_session_expiry(redirect_path, redirect_message)
        nil
      end
    end

    # Stores authentication session data
    #
    # @param session_key [Symbol, String] The session key to store to
    # @param value [Object] The value to store (typically an ID or hash)
    def store_authentication_session(session_key, value)
      session[session_key] = value
    end

    # Clears authentication session data
    #
    # @param session_keys [Array<Symbol, String>] The session keys to clear
    def clear_authentication_session(*session_keys)
      session_keys.each do |key|
        session[key] = nil
      end
    end

    # Validates session expiry against a timestamp
    #
    # @param session_data [Hash] The session data containing expiry information
    # @param expiry_key [String, Symbol] The key in session_data that contains expiry timestamp
    # @return [Boolean] true if not expired, false otherwise
    def validate_session_expiry(session_data, expiry_key = "expires_at")
      return false if session_data.blank?
      return true unless session_data[expiry_key]

      epoch_seconds(session_data[expiry_key]) > Time.current.to_i
    end

    # Loads a record from session with additional validation
    #
    # @param session_key [Symbol, String] The session key containing the record ID
    # @param model_class [Class] The model class to load
    # @param validations [Hash] Additional validations to perform
    # @return [ActiveRecord::Base, nil] The loaded record or nil
    # rubocop:disable Metrics/CyclomaticComplexity
    def load_session_record(session_key, model_class, validations = {})
      return nil if session[session_key].blank?

      record = model_class.find_by(id: session[session_key])
      return nil if record.blank?

      # Check OTP expiry if requested
      if validations[:check_otp_expiry] && record.respond_to?(:otp_expired?)
        return nil if record.otp_expired?
      end

      # Check status_id if provided
      if validations[:status_id] && record.respond_to?(:user_email_status_id)
        return nil if record.user_email_status_id != validations[:status_id]
      end

      # Run custom validation if provided
      if validations[:custom]
        return nil unless validations[:custom].call(record)
      end

      record
    end

    # rubocop:enable Metrics/CyclomaticComplexity

    def current_account
      current_resource
    end

    def current_session_public_id
      @current_session_public_id
    end

    def current_resource
      return @current_resource if defined?(@current_resource)

      @current_resource = load_current_resource
    end

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity
    def log_in(resource, record_login_audit: true, token_kind_id: "BROWSER_WEB", require_totp_check: true)
      return { status: :login_forbidden } unless resource.login_allowed?

      check_login_cooldown!(resource)

      reset_session

      # Clear any existing auth cookies to prevent conflicts with old sessions
      # This ensures we don't have duplicate cookies with different domains/paths
      # Note: We clear cookies before setting new ones, but preserve @current_resource
      # which will be set to the logged-in user after successful authentication
      cookies.delete(ACCESS_COOKIE_KEY, cookie_deletion_options)
      cookies.delete(REFRESH_COOKIE_KEY, cookie_deletion_options)
      clear_dbsc_cookie!
      clear_device_id_cookie!

      if require_totp_check
        totp_result = check_totp_requirement(resource)
        return totp_result if totp_result
      end

      session_limit_state = session_limit_state_for(resource)

      if session_limit_state == :hard_reject
        Rails.event.notify(
          "session.limit.hard_reject",
          "#{resource_type}_id": resource.id,
          ip_address: request_ip_address,
        )
        return {
          status: :session_limit_hard_reject,
          http_status: :conflict,
          message: SESSION_LIMIT_HARD_REJECT_MESSAGE,
        }
      end

      is_restricted = session_limit_state == :issue_restricted
      store_pending_login_resource(resource) if is_restricted

      kind_id = resolve_token_kind_id(token_kind_id)

      # Create token with appropriate status
      token_status = is_restricted ? token_class::STATUS_RESTRICTED : token_class::STATUS_ACTIVE
      token_record = create_login_token_record(resource, kind_id, status: token_status)

      # Generate SHA3-based refresh token
      # Must use writing role explicitly because GET-based OAuth callbacks
      # are auto-routed to the reading replica by DatabaseSelector middleware.
      restricted_expires_at = is_restricted ? restricted_session_expires_at : nil
      refresh_plain =
        TokenRecord.connected_to(role: :writing) do
          token_record.rotate_refresh_token!(lapses_at: restricted_expires_at)
        end

      if is_restricted
        Rails.event.notify(
          "session.restricted.issued",
          "#{resource_type}_id": resource.id,
          user_token_id: token_record.public_id,
          expires_at: restricted_expires_at&.iso8601,
          ip_address: request_ip_address,
        )
      end

      adopt_preference_for!(resource) if respond_to?(:adopt_preference_for!, true)

      # Generate JWT access token with explicit resource_type
      now = Time.current
      access_expires_at = access_token_expires_at_for(token_record, now: now)
      refresh_cookie_expires_at = refresh_cookie_expires_at_for(token_record)

      # Determine amr from token_kind_id
      amr_value = normalize_amr(token_kind_id)

      access_token = Token.encode(
        resource,
        host: request.host,
        session_public_id: token_record.public_id,
        resource_type: resource_type,
        expires_at: access_expires_at,
        preferences: build_auth_preference_snapshot(resource),
        acr: "aal1",
        amr: amr_value,
      )

      # Always set cookies (even for JSON responses - required for Edge/SPA)
      set_auth_cookies(
        access_token: access_token, refresh_token: refresh_plain,
        device_id: token_record.device_id,
        access_expires_at: access_expires_at,
        refresh_expires_at: refresh_cookie_expires_at,
        dbsc_token: dbsc_cookie_value_for(token_record),
        dbsc_expires_at: dbsc_cookie_expires_at_for(token_record),
      )
      issue_dbsc_registration_header_for(token_record)

      # Populate Current.actor immediately so same-request code sees the authenticated resource
      populate_current_attributes!(resource, nil)
      @_current_resource_resolved = true

      Sign::Risk::Emitter.emit(
        "session_issued",
        **risk_actor_payload(resource.id),
        user_token_id: token_record.public_id,
        ip: request&.remote_ip,
        user_agent: request&.user_agent,
        request_id: request&.request_id,
        meta: { auth_method: token_kind_id, restricted: is_restricted },
      )

      record_audit(AUDIT_EVENTS[:logged_in], resource: resource) if record_login_audit

      result = {
        status: :success,
        access_token: access_token,
        refresh_token: refresh_plain,
        token_type: "Bearer",
        expires_in: expires_in_for(access_expires_at, now: now),
        dbsc: dbsc_payload_for(token_record),
      }

      # If session is restricted, issue session limit gate and indicate need for session management
      if is_restricted
        result[:restricted] = true
        result[:session_management_required] = true
        issue_session_limit_gate!(
          return_to: session_limit_gate_return_to,
          flow: session_limit_gate_flow,
        )
      end

      result
    end

    def refresh_access_token(refresh_plain)
      clear_refresh_failure!

      refresh_public_id, = token_class.parse_refresh_token(refresh_plain.to_s)
      token_record = find_refresh_token_record(refresh_public_id)
      return handle_restricted_refresh_rejected(token_record, refresh_public_id) if token_record&.restricted?

      return handle_refresh_binding_denied(
        token_record,
        refresh_public_id,
      ) unless refresh_binding_allowed?(token_record)

      result = Sign::RefreshTokenService.call(refresh_token: refresh_plain)
      previous_token_record = result[:previous_token] || token_record
      token_record = result[:token]
      new_refresh_plain = result[:refresh_token]

      return handle_missing_refresh_token(refresh_public_id) unless token_record.is_a?(token_class)

      # Load resource from token record
      # No special test handling - same code path for all environments
      resource = token_record.public_send(resource_type)

      return handle_inactive_resource(resource, refresh_public_id, token_record) unless resource&.active?

      build_refreshed_session(
        resource, token_record, new_refresh_plain,
        previous_token_record: previous_token_record,
      )
    rescue Sign::InvalidRefreshToken => e
      handle_invalid_refresh_token(e, refresh_public_id, token_record)
    rescue StandardError => e
      Rails.event.error(
        "auth.token.refresh.error",
        error_class: e.class.name,
        message: e.message,
        exception: e,
      )
      handle_refresh_error(e, refresh_public_id, resource)
    end

    def refresh_failure_status
      @refresh_failure_status || :unauthorized
    end

    def refresh_failure_code
      @refresh_failure_code || "invalid_refresh_token"
    end

    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def log_out
      resource = current_resource

      destroy_refresh_token_from_cookie
      clear_auth_cookies!

      record_audit(AUDIT_EVENTS[:logged_out], resource: resource) if resource
      reset_session
    end

    def transparent_refresh_access_token
      return if logged_in?

      # Loop guard: prevents infinite refresh loops within the same request
      return if request.env[Auth::IoKeys::Env::AUTH_REFRESHED_FLAG]

      refresh_plain = cookies[REFRESH_COOKIE_KEY]
      return if refresh_plain.blank?

      # Mark as refreshed to prevent recursion
      request.env[Auth::IoKeys::Env::AUTH_REFRESHED_FLAG] = true

      refreshed = refresh_access_token(refresh_plain)
      unless refreshed
        Rails.event.debug("auth.transparent_refresh.failed")
        clear_auth_cookies!
        return
      end

      Rails.event.debug("auth.transparent_refresh.success", user_present: refreshed[:user].present?)
      @current_resource = refreshed[:user]
    end

    def authenticate!
      if logged_in?
        Sign::Risk::Enforcer.call(current_resource)
        return
      end

      if request.format.json?
        render json: { error: "Unauthorized" }, status: :unauthorized
      else
        Sign::Risk::Emitter.emit(
          "auth_required",
          ip: request&.remote_ip,
          user_agent: request&.user_agent,
          request_id: request&.request_id,
          path: request&.fullpath,
          method: request&.request_method,
        )
        rt = Base64.urlsafe_encode64(request.original_url)
        redirect_to(
          sign_in_url_with_return(rt),
          allow_other_host: true,
          alert: I18n.t("errors.messages.login_required"),
        )
      end
    end

    # Abstract methods - must be implemented by including modules
    def resource_class
      raise NotImplementedError, "resource_class must be implemented"
    end

    def token_class
      raise NotImplementedError, "token_class must be implemented"
    end

    def audit_class
      raise NotImplementedError, "audit_class must be implemented"
    end

    def resource_type
      raise NotImplementedError, "resource_type must be implemented"
    end

    def resource_foreign_key
      raise NotImplementedError, "resource_foreign_key must be implemented"
    end

    def test_header_key
      return Auth::IoKeys::Headers::TEST_CURRENT_RESOURCE unless Rails.env.test?

      actor_type = resource_type if respond_to?(:resource_type, true)
      case actor_type
      when "user"
        Auth::IoKeys::Headers::TEST_CURRENT_USER
      when "staff"
        Auth::IoKeys::Headers::TEST_CURRENT_STAFF
      when "viewer"
        Auth::IoKeys::Headers::TEST_CURRENT_VIEWER
      else
        Auth::IoKeys::Headers::TEST_CURRENT_RESOURCE
      end
    rescue StandardError
      Auth::IoKeys::Headers::TEST_CURRENT_RESOURCE
    end

    def sign_in_url_with_return(return_to)
      raise NotImplementedError, "sign_in_url_with_return must be implemented"
    end

    # Authorization abstract methods - RBAC / ABAC placeholders
    def am_i_user?
      raise NotImplementedError, "am_i_user? must be implemented"
    end

    def am_i_staff?
      raise NotImplementedError, "am_i_staff? must be implemented"
    end

    def am_i_owner?
      raise NotImplementedError, "am_i_owner? must be implemented"
    end

    included do
      include ::Sign::ErrorResponses
      include ::SessionLimitGate

      if respond_to?(:rescue_from)
        rescue_from LoginCooldownError, with: :render_login_cooldown
      end

      if respond_to?(:helper_method)
        helper_method :current_account, :current_session_public_id, :current_session_restricted?
      end
    end

    # ==========================================================================
    # 5) Abstract contract & policy DSL (controller class API)
    # ==========================================================================
    class_methods do
      # Declare policy for controller or specific actions (only/except).
      def access_policy_rules
        ACCESS_POLICY_RULES.fetch_or_store(self) do
          parent_rules =
            if superclass.respond_to?(:access_policy_rules)
              superclass.access_policy_rules
            else
              []
            end
          parent_rules.dup
        end
      end

      def access_policy(policy, only: nil, except: nil, **options)
        policy = policy.to_sym
        raise InvalidPolicyError, "Invalid policy: #{policy.inspect}" unless VALID_POLICIES.include?(policy)

        rule = {
          policy: policy,
          only: Array(only).map(&:to_s).presence,
          except: Array(except).map(&:to_s).presence,
          options: options,
        }

        ACCESS_POLICY_RULES[self] = access_policy_rules + [rule]
      end

      # Readable shortcuts.
      def public_strict!(**) = access_policy(:public_strict, **)

      def auth_required!(**) = access_policy(:auth_required, **)

      def guest_only!(**) = access_policy(:guest_only, **)

      # --- Skip guardrails ---
      # Disallow removing enforce_access_policy! via skip_before_action.
      def skip_before_action(*filters, **options)
        # Note: In Ruby 4.0+/Rails 8+, some callers pass Hash as positional argument
        # instead of keyword arguments. Filter out non-symbol entries.
        flattened = filters.flatten
        action_names =
          flattened.filter_map do |filter|
            next unless filter.respond_to?(:to_sym) && !filter.is_a?(Hash)

            filter.to_sym
          end
        if action_names.include?(:enforce_access_policy!)
          raise SkipNotAllowedError, "skip_before_action :enforce_access_policy! is prohibited (#{name})"
        end

        super
      end

      # Some code uses skip_action_callback, so lock this down too.
      def skip_action_callback(*args, **kwargs)
        # skip_action_callback(:process_action, :before, :enforce_access_policy!)
        if args.map(&:to_sym).include?(:enforce_access_policy!)
          raise SkipNotAllowedError, "skip_action_callback :enforce_access_policy! is prohibited (#{name})"
        end

        super
      end
    end

    private

    # ----------------------------------------------------------------------
    # 3-2) Bulletin private helpers
    # ----------------------------------------------------------------------

    def find_unread_bulletin
      bulletin_association_for_resource&.unread&.oldest_first&.first
    end

    def mark_current_bulletin_as_read!
      current_bulletin&.mark_as_read!
    end

    def bulletin_association_for_resource
      resource = current_resource
      return nil unless resource

      case resource
      when User then resource.user_bulletins
      when Staff then resource.staff_bulletins
      end
    end

    def create_welcome_bulletin!(resource)
      case resource
      when User
        resource.user_bulletins.create!(
          title: I18n.t("sign.app.in.bulletins.welcome.title"),
          body: I18n.t("sign.app.in.bulletins.welcome.body"),
        )
      when Staff
        resource.staff_bulletins.create!(
          title: I18n.t("sign.org.in.bulletins.welcome.title"),
          body: I18n.t("sign.org.in.bulletins.welcome.body"),
        )
      end
    end

    # ======================================================================
    # 6) Private request/cookie/token I/O helpers
    # ======================================================================

    # ----------------------------------------------------------------------
    # 6-1) Withdrawal gate (Request I/O boundary)
    # ----------------------------------------------------------------------

    def enforce_withdrawal_gate!
      return unless logged_in?
      return unless current_resource
      return unless current_resource.respond_to?(:deactivated?)
      return unless current_resource.deactivated?

      # Allowlist: configuration edit and withdrawal flow
      return if withdrawal_gate_allowlisted?

      # API/JSON: return 403 Forbidden
      if request.format.json? || !request.format.html?
        render json: { error: "WITHDRAWAL_REQUIRED" }, status: :forbidden
        return
      end

      # HTML: redirect to configuration edit page
      safe_redirect_to(withdrawal_gate_redirect_path, fallback: "/configuration/edit", status: :found)
    end

    def withdrawal_gate_allowlisted?
      # Allowlist: configuration edit
      return true if controller_path.end_with?("/configurations") && action_name == "edit"

      # Allowlist: withdrawal controller actions
      return true if controller_path.end_with?("configuration/withdrawals") && %w(new edit update
                                                                                  create).include?(action_name)

      # Allowlist: health/assets (rarely needed but safe)
      return true if controller_path == "rails/health"

      false
    end

    def withdrawal_gate_redirect_path
      if respond_to?(:edit_sign_app_configuration_path, true)
        edit_sign_app_configuration_path(ri: params[Auth::IoKeys::Params::RI])
      elsif respond_to?(:edit_sign_org_configuration_path, true)
        edit_sign_org_configuration_path(ri: params[Auth::IoKeys::Params::RI])
      else
        "/configuration/edit"
      end
    rescue StandardError => e
      Rails.event.error("auth.withdrawal_gate.path_resolution_failed", message: e.message, exception: e)
      "/configuration/edit"
    end

    # ----------------------------------------------------------------------
    # 6-2) Cookie/session/header accessors (I/O boundary)
    # ----------------------------------------------------------------------
    def cookie_options
      Core::CookieOptions.for(
        surface: Core::Surface.current(request),
        request: request,
        httponly: true,
        same_site: :lax,
        path: "/",
        domain: true,
      )
    end

    def cookie_deletion_options
      Core::CookieOptions.for(
        surface: Core::Surface.current(request),
        request: request,
        same_site: :lax,
        path: "/",
        domain: true,
      ).except(:expires, :httponly, :secure, :same_site)
    end

    def device_cookie_key
      Auth::CookieName.device(refresh_cookie_key: REFRESH_COOKIE_KEY)
    end

    def device_cookie_options(expires_at:)
      cookie_options.merge(expires: expires_at)
    end

    def set_device_id_cookie!(device_id, expires_at:)
      cookies[device_cookie_key] = device_cookie_options(expires_at: expires_at).merge(value: device_id)
    end

    def clear_device_id_cookie!
      cookies.delete(device_cookie_key, cookie_deletion_options)
    end

    def clear_auth_cookies!
      cookies.delete(ACCESS_COOKIE_KEY, cookie_deletion_options)
      cookies.delete(REFRESH_COOKIE_KEY, cookie_deletion_options)
      clear_dbsc_cookie!
      clear_device_id_cookie!
      @current_resource = nil
    end

    def read_device_id_cookie
      store = cookies
      cookie_value = store&.[](device_cookie_key)
      stored_value =
        if cookie_value.is_a?(Hash)
          cookie_value[:value] || cookie_value["value"]
        else
          cookie_value
        end
      return stored_value.to_s.presence if stored_value.to_s.present?

      request.headers[Auth::IoKeys::Headers::DEVICE_ID].to_s.presence
    end

    def set_auth_cookies(access_token:, refresh_token:, device_id:, access_expires_at:, refresh_expires_at:,
                         dbsc_token: nil, dbsc_expires_at: nil)
      # Access cookie
      cookies[ACCESS_COOKIE_KEY] = cookie_options.merge(
        value: access_token,
        expires: access_expires_at,
      )
      # Refresh cookie
      cookies[REFRESH_COOKIE_KEY] = cookie_options.merge(
        value: refresh_token,
        expires: refresh_expires_at,
      )
      set_dbsc_cookie!(dbsc_token, expires_at: dbsc_expires_at) if dbsc_token.present? && dbsc_expires_at.present?
      set_device_id_cookie!(device_id, expires_at: refresh_expires_at)
    end

    def set_dbsc_cookie!(token, expires_at:)
      cookies[DBSC_COOKIE_KEY] = cookie_options.merge(
        value: token,
        expires: expires_at,
      )
    end

    def clear_dbsc_cookie!
      cookies.delete(DBSC_COOKIE_KEY, cookie_deletion_options)
    end

    def extract_access_token(cookie_key)
      return nil unless respond_to?(:request, true) && request

      Auth::AuthorizationHeader.bearer_token(request) || cookies[cookie_key]
    end

    # ----------------------------------------------------------------------
    # 6-3) Audit/occurrence writing (side-effect boundary)
    # ----------------------------------------------------------------------
    def record_audit(event_id, resource:, actor: resource)
      return unless resource && event_id

      Rails.event.debug(
        "auth.audit.recording",
        event_id: event_id,
        resource_id: resource&.id,
      )

      # Delegate to AuditWriter with best-effort semantics
      # This ensures audit failures do not block authentication
      Auth::AuditWriter.write(
        audit_class,
        event_id,
        resource: resource,
        actor: actor,
        ip_address: request_ip_address,
      )
    end

    def write_refresh_occurrence(event_type:, token_record:, reason:, device_source:)
      model_class = occurrence_model_class
      return unless model_class

      body = SecureRandom.uuid
      token_record_id = token_record&.public_id

      model_class.create!(
        body: body,
        event_type: event_type,
        status_id: 1,
        context: {
          host: request.host,
          request_id: request.request_id,
          ip_hash: occurrence_ip_hash,
          device_source: device_source,
          token_family_id: token_record&.refresh_token_family_id,
          token_id: token_record_id,
          generation: token_record&.refresh_token_generation,
          reason: reason,
        },
      )
    rescue StandardError => e
      Rails.event.notify(
        "#{resource_type}.occurrence.write_failed",
        event_type: event_type,
        reason: reason,
        error_class: e.class.name,
        error_message: e.message,
      )
    end

    def occurrence_model_class
      return UserOccurrence if resource_type == "user"
      return StaffOccurrence if resource_type == "staff"

      nil
    end

    def occurrence_ip_hash
      ip = request_ip_address.to_s
      secret = Rails.app.creds.option(:OCCURRENCE_HMAC_SECRET).presence
      OpenSSL::HMAC.hexdigest("SHA256", secret, ip)
    end

    # ----------------------------------------------------------------------
    # 6-4) Refresh error handling and token/device guards
    # ----------------------------------------------------------------------
    def handle_missing_refresh_token(refresh_public_id)
      set_refresh_failure!(:unauthorized, "invalid_refresh_token")

      Rails.event.notify(
        "#{resource_type}.token.refresh.failed",
        refresh_token_id: refresh_public_id,
        reason: "token_not_found",
        ip_address: request_ip_address,
      )

      Sign::Risk::Emitter.emit(
        "refresh_failed",
        user_token_id: refresh_public_id,
        ip: request&.remote_ip,
        user_agent: request&.user_agent,
        request_id: request&.request_id,
        meta: { reason: "token_not_found" },
      )

      nil
    end

    def handle_inactive_resource(resource, refresh_public_id, token_record)
      if resource.respond_to?(:deactivated?) && resource.deactivated?
        set_refresh_failure!(:forbidden, "withdrawal_required")
      else
        set_refresh_failure!(:unauthorized, "invalid_refresh_token")
      end

      Rails.event.notify(
        "#{resource_type}.token.refresh.failed",
        "#{resource_type}_id": resource&.id,
        refresh_token_id: refresh_public_id,
        reason: "#{resource_type}_inactive",
        ip_address: request_ip_address,
      )

      Sign::Risk::Emitter.emit(
        "refresh_failed",
        **risk_actor_payload(resource&.id),
        user_token_id: refresh_public_id,
        ip: request&.remote_ip,
        user_agent: request&.user_agent,
        request_id: request&.request_id,
        meta: { reason: "#{resource_type}_inactive" },
      )

      # S3: Do not destroy token - only revoke it
      # This prevents destructive behavior in transparent refresh
      TokenRecord.connected_to(role: :writing) do
        next if token_record.blank?

        now = Time.current
        family_id = token_record.refresh_token_family_id.to_s
        expiry_column = token_expiry_column(token_record.class)
        expiry_attrs = { expiry_column => now, :updated_at => now }
        expiry_attrs[:revoked_at] =
          now if expiry_column == :expired_at && token_record.class.column_names.include?("revoked_at")
        if family_id.present?
          token_record.class.where(:refresh_token_family_id => family_id, expiry_column => nil)
            .find_each do |record|
              record.update!(expiry_attrs)
            end
        elsif token_record.public_send(expiry_column).nil?
          token_record.update!(expiry_attrs.except(:updated_at))
        end
      end
      nil
    end

    # rubocop:disable Metrics/MethodLength
    def build_refreshed_session(resource, token_record, new_refresh_plain, previous_token_record: nil)
      access_expires_at = access_token_expires_at_for(token_record)
      refresh_cookie_expires_at = refresh_cookie_expires_at_for(token_record)

      # Refresh forces downgrade to aal1 and clears amr
      new_access_token = Token.encode(
        resource,
        host: request.host,
        session_public_id: token_record.public_id,
        resource_type: resource_type,
        expires_at: access_expires_at,
        preferences: build_auth_preference_snapshot(resource),
        acr: "aal1",
        amr: nil,
      )

      set_auth_cookies(
        access_token: new_access_token,
        refresh_token: new_refresh_plain,
        device_id: token_record.device_id,
        access_expires_at: access_expires_at,
        refresh_expires_at: refresh_cookie_expires_at,
        dbsc_token: dbsc_cookie_value_for(token_record),
        dbsc_expires_at: dbsc_cookie_expires_at_for(token_record),
      )

      Sign::Risk::Emitter.emit(
        "refresh_rotated",
        **risk_actor_payload(resource.id),
        user_token_id: token_record.public_id,
        ip: request&.remote_ip,
        user_agent: request&.user_agent,
        request_id: request&.request_id,
      )

      Rails.event.notify(
        "#{resource_type}.token.refreshed",
        "#{resource_type}_id": resource.id,
        old_refresh_token_id: previous_token_record&.public_id || token_record.public_id,
        new_refresh_token_id: token_record.public_id,
        ip_address: request_ip_address,
      )

      # S1: Audit with best-effort semantics - failure does not block refresh
      # AuditWriter.write handles exceptions internally and notifies observers
      record_audit(AUDIT_EVENTS[:token_refreshed], resource: resource)

      Sign::Risk::Enforcer.call(resource)

      issue_dbsc_registration_header_for(token_record)

      {
        access_token: new_access_token,
        refresh_token: new_refresh_plain,
        token_type: "Bearer",
        expires_in: expires_in_for(access_expires_at),
        user: resource,
        dbsc: dbsc_payload_for(token_record),
      }
    end
    # rubocop:enable Metrics/MethodLength

    def request_ip_address
      (respond_to?(:request, true) && request) ? request.remote_ip : nil
    end

    def handle_invalid_refresh_token(exception, refresh_public_id, token_record = nil)
      set_refresh_failure!(:unauthorized, "invalid_refresh_token")

      if exception.message == "refresh_token_reuse_detected"
        write_refresh_occurrence(
          event_type: "refresh_reuse_detected",
          token_record: token_record || find_refresh_token_record(refresh_public_id),
          reason: "reuse",
          device_source: refresh_device_source,
        )
      end

      Rails.event.notify(
        "#{resource_type}.token.refresh.failed",
        refresh_token_id: refresh_public_id,
        reason: exception.class.name,
        ip_address: request_ip_address,
      )

      Sign::Risk::Emitter.emit(
        "refresh_failed",
        user_token_id: refresh_public_id,
        ip: request&.remote_ip,
        user_agent: request&.user_agent,
        request_id: request&.request_id,
        meta: { reason: exception.class.name },
      )

      nil
    end

    def handle_refresh_binding_denied(token_record, refresh_public_id)
      reason = @refresh_device_reason || @refresh_dbsc_reason || "missing"
      event_type =
        if token_record&.binding_method_dbsc?
          "refresh_dbsc_denied"
        else
          (reason == "mismatch") ? "refresh_device_mismatch" : "refresh_device_missing"
        end
      write_refresh_occurrence(
        event_type: event_type,
        token_record: token_record,
        reason: reason,
        device_source: refresh_binding_source(token_record),
      )

      set_refresh_failure!(:unauthorized, "invalid_refresh_token")
      destroy_refresh_token_from_cookie
      clear_auth_cookies!

      Rails.event.notify(
        "#{resource_type}.token.refresh.failed",
        refresh_token_id: refresh_public_id,
        reason: binding_failure_reason(reason, token_record),
        ip_address: request_ip_address,
      )

      nil
    end

    def handle_refresh_error(exception, refresh_public_id, resource)
      set_refresh_failure!(:unauthorized, "invalid_refresh_token")

      Rails.event.notify(
        "#{resource_type}.token.refresh.error",
        "#{resource_type}_id": resource&.id,
        refresh_token_id: refresh_public_id,
        error_message: exception.message,
        ip_address: request_ip_address,
      )

      Sign::Risk::Emitter.emit(
        "refresh_failed",
        **risk_actor_payload(resource&.id),
        user_token_id: refresh_public_id,
        ip: request&.remote_ip,
        user_agent: request&.user_agent,
        request_id: request&.request_id,
        meta: { error_class: exception.class.name },
      )

      nil
    end

    def handle_restricted_refresh_rejected(token_record, refresh_public_id)
      expired = token_record.refresh_expires_at.present? && token_record.refresh_expires_at <= Time.current

      expiry_column = token_expiry_column(token_record.class)
      if expired && token_record.public_send(expiry_column).nil?
        TokenRecord.connected_to(role: :writing) do
          token_record.revoke!
        end
        Rails.event.notify(
          "session.restricted.expired",
          user_token_id: token_record.public_id,
          "#{resource_type}_id": token_record.public_send("#{resource_type}_id"),
        )
      end

      set_refresh_failure!(:forbidden, "restricted_session")

      Rails.event.notify(
        "#{resource_type}.token.refresh.failed",
        refresh_token_id: refresh_public_id,
        reason: expired ? "restricted_expired" : "restricted_session",
        ip_address: request_ip_address,
      )

      nil
    end

    def find_refresh_token_record(refresh_public_id)
      return nil if refresh_public_id.blank?

      find_logic = -> { token_class.find_by(public_id: refresh_public_id) }
      TokenRecord.connected_to(role: :reading, &find_logic)
    end

    def set_refresh_failure!(status, code)
      @refresh_failure_status = status
      @refresh_failure_code = code
    end

    def clear_refresh_failure!
      @refresh_failure_status = nil
      @refresh_failure_code = nil
      @refresh_device_reason = nil
      @refresh_dbsc_reason = nil
    end

    def refresh_binding_allowed?(token_record)
      return refresh_dbsc_allowed?(token_record) if token_record&.binding_method_dbsc?

      refresh_device_allowed?(token_record)
    end

    def refresh_device_allowed?(token_record)
      cookie_device_id = read_device_id_cookie

      if cookie_device_id.blank?
        @refresh_device_reason = "missing"
        return false
      end

      return true if token_record.blank?

      if token_record.device_id_digest.blank?
        if token_record.device_id.present?
          if token_record.device_id == cookie_device_id
            return true
          end

          @refresh_device_reason = "mismatch"
          return false
        end

        @refresh_device_reason = "missing"
        return false
      end

      # Compare using SHA3-384 digest for security
      # Cookie contains plaintext device_id, DB stores digest
      presented_digest = digest_device_id(cookie_device_id)
      if token_record.device_id_digest.blank? || !secure_compare?(token_record.device_id_digest, presented_digest)
        @refresh_device_reason = "mismatch"
        return false
      end

      true
    end

    def refresh_dbsc_allowed?(token_record)
      return true if token_record.blank?
      return false unless token_record.dbsc_status_active?

      dbsc_cookie = cookies[DBSC_COOKIE_KEY].to_s.presence
      if dbsc_cookie.blank?
        @refresh_dbsc_reason = "missing_bound_cookie"
        return false
      end

      if token_record.dbsc_session_id.to_s.blank? || token_record.dbsc_session_id != dbsc_cookie
        @refresh_dbsc_reason = "session_id_mismatch"
        return false
      end

      true
    end

    def refresh_device_source
      header_present = request.headers[Auth::IoKeys::Headers::DEVICE_ID].to_s.present?
      cookie_present = read_device_id_cookie.present?
      return "both" if header_present && cookie_present
      return "header" if header_present
      return "cookie" if cookie_present

      "none"
    end

    def refresh_dbsc_source
      session_present = request.headers[Auth::IoKeys::Headers::DBSC_SESSION_ID].to_s.present?
      response_present = request.headers[Auth::IoKeys::Headers::DBSC_RESPONSE].to_s.present?
      return "both" if session_present && response_present
      return "session_id" if session_present
      return "response" if response_present

      "none"
    end

    def refresh_binding_source(token_record)
      return refresh_dbsc_source if token_record&.binding_method_dbsc?

      refresh_device_source
    end

    def binding_failure_reason(reason, token_record)
      prefix = token_record&.binding_method_dbsc? ? "dbsc" : "device"
      "#{prefix}_#{reason}"
    end

    def load_current_resource
      if Rails.env.test?
        resource = load_from_test_header
        if resource
          populate_current_attributes!(resource, nil)
          return resource
        end
      end

      resource = load_from_token
      return nil if resource_withdrawn?(resource)

      resource
    end

    def load_from_test_header
      return nil unless respond_to?(:request, true) && request

      header_key = test_header_key
      test_id = request.headers[header_key]
      if test_id.blank? && header_key == Auth::IoKeys::Headers::TEST_CURRENT_RESOURCE
        test_id = request.headers[Auth::IoKeys::Headers::TEST_CURRENT_RESOURCE] ||
          request.headers[Auth::IoKeys::Headers::TEST_CURRENT_USER] ||
          request.headers[Auth::IoKeys::Headers::TEST_CURRENT_STAFF] ||
          request.headers[Auth::IoKeys::Headers::TEST_CURRENT_VIEWER]
      end
      return nil unless test_id

      resource = resource_class.find_by(id: test_id)
      if resource
        @bypass_withdrawn_check = true
        test_session_id = request.headers[Auth::IoKeys::Headers::TEST_SESSION_PUBLIC_ID]
        @current_session_public_id = test_session_id if test_session_id.present?
      end
      resource
    end

    def load_from_token
      access_token = extract_access_token(ACCESS_COOKIE_KEY)
      request_host = request&.host
      return nil if request_host.blank?

      result = Auth::CurrentResourceResolver.new(
        access_token: access_token,
        request_host: request_host,
        resource_type: resource_type,
        resource_class: resource_class,
        token_class: token_class,
        test_env: Rails.env.test?,
      ).call

      emit_actor_mismatch_event(result.payload) if result.failure_reason == :actor_mismatch
      @current_session_public_id = result.session_public_id if result.session_public_id.present?

      populate_current_attributes!(result.resource, result.payload) if result.resource.present?

      result.resource
    end

    # Populate Current.* attributes from JWT payload after successful authentication
    def populate_current_attributes!(resource, payload)
      return if resource.blank?

      Current.actor = resource
      Current.actor_type =
        case resource_type
        when "staff" then :staff
        when "customer" then :customer
        else :user
        end
      Current.session = @current_session_public_id
      Current.token = payload if payload.present?
      Current.domain = Core::Surface.current(request) if respond_to?(:request, true) && request.present?
    end

    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def emit_actor_mismatch_event(payload)
      act = Token.extract_act(payload)
      sub = Token.extract_subject(payload)

      Rails.event.notify(
        "authentication.actor_mismatch",
        expected: resource_type,
        actual: act,
        subject: sub,
        ip_address: request_ip_address,
      )

      Sign::Risk::Emitter.emit(
        "actor_mismatch",
        **risk_actor_payload(sub),
        ip: request&.remote_ip,
        user_agent: request&.user_agent,
        request_id: request&.request_id,
        meta: { expected: resource_type, actual: act },
      )
    end

    # Returns { user_id: id } or { staff_id: id } based on resource_type.
    # Used by Risk::Emitter to route events to the correct occurrence table.
    def risk_actor_payload(id)
      case resource_type
      when "staff"
        { staff_id: id }
      when "customer"
        { customer_id: id }
      else
        { user_id: id }
      end
    end

    def resource_withdrawn?(resource)
      return false unless resource&.respond_to?(:withdrawn?)
      return false if @bypass_withdrawn_check

      resource.withdrawn?
    end

    def destroy_refresh_token_from_cookie
      token_value = cookies[REFRESH_COOKIE_KEY]
      return unless token_value

      public_id, = token_class.parse_refresh_token(token_value)
      return unless public_id

      destroy_logic =
        -> {
          token_class.find_by(public_id: public_id)&.destroy
        }

      if Rails.env.test?
        destroy_logic.call
      else
        TokenRecord.connected_to(role: :writing, &destroy_logic)
      end
    rescue ActiveRecord::RecordNotDestroyed => e
      Rails.event.notify(
        "#{resource_type}.token.destroy.failed",
        token_id: public_id,
        error_message: e.message,
        ip_address: request_ip_address,
      )
    end

    # Handles session expiry by redirecting with appropriate message
    #
    # @param redirect_path [String, Symbol] Where to redirect
    # @param message_key [String] Translation key for the expiry message
    def handle_session_expiry(redirect_path, message_key)
      redirect_params = { notice: t(message_key) }
      # Preserve redirect parameter if present
      default_rd_key = Auth::IoKeys::Session::DEFAULT_RD
      redirect_params[Auth::IoKeys::Params::RD] = session[default_rd_key] if session[default_rd_key].present?
      redirect_to(redirect_path, redirect_params)
    end

    # ======================================================================
    # 7) Policy/domain decisions
    # ======================================================================
    # --- Policy enforcement methods ---

    def enforce_access_policy!
      rule = resolve_policy_rule

      policy = rule[:policy]
      options = rule[:options] || {}

      Rails.event.debug(
        "auth.policy.resolved",
        policy: policy,
        controller: self.class.name,
        action: action_name,
        rules_count: self.class.access_policy_rules.size,
      )

      case policy
      when :public_strict
        enforce_public_strict!(options)
      when :auth_required
        enforce_auth_required!(options)
      when :guest_only
        enforce_guest_only!(options)
      else
        raise InvalidPolicyError, "Unexpected policy: #{policy.inspect}"
      end
    end

    def resolve_policy_rule
      rule = resolve_access_policy_for(action_name)

      if rule.nil?
        Rails.event.warn("auth.policy.missing", controller: self.class.name, action: action_name)
        raise MissingPolicyError,
              "Missing access_policy for #{self.class.name}##{action_name}. " \
              "Declare one of: #{VALID_POLICIES.join(", ")}"
      end
      rule
    end

    def resolve_access_policy_for(action)
      action = action.to_s

      # Last rule wins so controller-wide policies can be overridden per action.
      rules = self.class.access_policy_rules
      return nil if rules.blank?

      rules.reverse_each do |rule|
        next if rule[:only].present? && rule[:only].exclude?(action)
        next if rule[:except].present? && rule[:except].include?(action)

        return rule
      end

      nil
    end

    # --- Behavior implementation (align with your auth stack) ---

    def enforce_public_strict!(_options = {})
      # If you avoid touching current_user/current_resource here,
      # the safest default is to do nothing.
      true
    end

    def enforce_auth_required!(options = {})
      # Example: use Authentication::Base logged_in? / current_resource.
      return true if respond_to?(:logged_in?) && logged_in?

      # Branch HTML vs API (or delegate to your responder).
      if request.format.json? || options[:request_format] == :json
        handle_auth_required_json(options)
      else
        handle_auth_required_html(options)
      end
    end

    def enforce_guest_only!(options = {})
      # Guest-only policy: block logged-in users.
      return true unless respond_to?(:logged_in?) && logged_in?

      # Exception: deactivated users should be handled by withdrawal gate, not guest_only
      if current_resource.respond_to?(:deactivated?) && current_resource.deactivated?
        return true
      end

      if request.format.json? || options[:request_format] == :json
        handle_guest_only_json(options)
      else
        handle_guest_only_with_status_checks(options)
      end
    end

    def create_login_token_record(resource, token_kind_id, status: nil)
      TokenRecord.connected_to(role: :writing) do
        token_attributes = { resource_foreign_key => resource.id }
        # Determine kind column based on resource type (user_token_kind_id or staff_token_kind_id)
        kind_column = "#{resource_type}_token_kind_id"
        if token_class.column_names.include?(kind_column)
          ensure_token_kind_exists!(token_kind_id)
          token_attributes[kind_column] = token_kind_id
        end

        # Set status if provided (for restricted sessions)
        token_attributes[:status] = status if status.present?
        token_attributes.merge!(default_dbsc_token_attributes)
        token_attributes.merge!(scheduled_login_token_attributes)

        token_class.create!(token_attributes)
      end
    end

    def default_dbsc_token_attributes
      case resource_type
      when "user"
        {
          user_token_binding_method_id: UserTokenBindingMethod::LEGACY,
          user_token_dbsc_status_id: UserTokenDbscStatus::NOTHING,
        }
      when "staff"
        {
          staff_token_binding_method_id: StaffTokenBindingMethod::LEGACY,
          staff_token_dbsc_status_id: StaffTokenDbscStatus::NOTHING,
        }
      when "customer"
        {
          customer_token_binding_method_id: CustomerTokenBindingMethod::LEGACY,
          customer_token_dbsc_status_id: CustomerTokenDbscStatus::NOTHING,
        }
      else
        {}
      end
    end

    def resolve_token_kind_id(raw_kind_id)
      return raw_kind_id unless raw_kind_id.is_a?(String)

      kind_column = "#{resource_type}_token_kind_id"
      return raw_kind_id unless token_class.columns_hash[kind_column]&.type == :integer

      kind_model = token_kind_model
      if kind_model.column_names.include?("code")
        begin
          return kind_model.find_by!(code: raw_kind_id).id
        rescue ActiveRecord::RecordNotFound
          Rails.event.error(
            "auth.token.kind_missing",
            kind_model: kind_model.name,
            code: raw_kind_id,
            resource_type: resource_type,
          )
          raise ActiveRecord::RecordNotFound,
                "Missing #{kind_model.name} code=#{raw_kind_id} for #{resource_type} login"
        end
      end

      resolved =
        case [resource_type, raw_kind_id]
        when ["staff", "BROWSER_WEB"] then StaffTokenKind::BROWSER_WEB
        when ["staff", "CLIENT_IOS"] then StaffTokenKind::CLIENT_IOS
        when ["staff", "CLIENT_ANDROID"] then StaffTokenKind::CLIENT_ANDROID
        when ["user", "BROWSER_WEB"] then UserTokenKind::BROWSER_WEB
        when ["user", "CLIENT_IOS"] then UserTokenKind::CLIENT_IOS
        when ["user", "CLIENT_ANDROID"] then UserTokenKind::CLIENT_ANDROID
        when ["customer", "BROWSER_WEB"] then CustomerTokenKind::BROWSER_WEB
        when ["customer", "CLIENT_IOS"] then CustomerTokenKind::CLIENT_IOS
        when ["customer", "CLIENT_ANDROID"] then CustomerTokenKind::CLIENT_ANDROID
        end

      return resolved if resolved

      raise ActiveRecord::RecordNotFound, "Missing #{kind_model.name} for code=#{raw_kind_id}"
    end

    def ensure_token_kind_exists!(token_kind_id)
      return if token_kind_id.blank?

      kind_model = token_kind_model
      kind_model.find(token_kind_id)
    rescue ActiveRecord::RecordNotFound
      Rails.event.error(
        "auth.token.kind_missing",
        kind_model: kind_model.name,
        id: token_kind_id,
        resource_type: resource_type,
      )
      raise ActiveRecord::RecordNotFound,
            "Missing #{kind_model.name} id=#{token_kind_id} for #{resource_type} login"
    end

    def token_kind_model
      case resource_type
      when "user" then UserTokenKind
      when "staff" then StaffTokenKind
      when "customer" then CustomerTokenKind
      else
        raise ActiveRecord::RecordNotFound, "Missing token kind model for resource_type=#{resource_type}"
      end
    end

    # ----------------------------------------------------------------------
    # 7-1) MFA/session-limit domain decisions
    # ----------------------------------------------------------------------
    def check_totp_requirement(resource)
      return unless mfa_required_for?(resource)

      set_pending_mfa!(resource: resource, primary: "mfa")
      { status: :mfa_required }
    end

    def set_pending_mfa!(resource:, primary:, return_to: nil, ri: nil, auth_method: nil)
      issued_at = Time.current.to_i
      expires_at = pending_mfa_ttl.from_now.to_i
      session[:pending_mfa] = {
        "public_id" => SecureRandom.hex(16),
        "user_id" => resource.id,
        "resource_type" => resource_type,
        "primary" => primary.to_s,
        "auth_method" => auth_method.to_s.presence || primary.to_s,
        "return_to" => return_to.presence,
        "ri" => ri.to_s.presence,
        "issued_at" => issued_at,
        "expires_at" => expires_at,
        "attempts" => 0,
      }
      # Backward compatibility for existing controllers still using mfa_user_id.
      session[:mfa_user_id] = resource.id
    end

    def pending_mfa
      raw = session[:pending_mfa]
      return nil unless raw.is_a?(Hash)

      raw.with_indifferent_access
    end

    def pending_mfa_ttl
      10.minutes
    end

    def pending_mfa_valid?
      data = pending_mfa
      return false unless data

      expires_at = epoch_seconds(data[:expires_at])
      if expires_at.positive?
        return false if Time.current.to_i >= expires_at
      else
        issued_at = epoch_seconds(data[:issued_at])
        return false if issued_at <= 0
        return false if Time.zone.at(issued_at) < pending_mfa_ttl.ago
      end

      true
    end

    def pending_mfa_user
      return nil unless pending_mfa_valid?

      user_id = pending_mfa[:user_id]
      return nil if user_id.blank?

      klass = respond_to?(:resource_class, true) ? resource_class : ::User
      klass.find_by(id: user_id)
    end

    def clear_pending_mfa!
      session.delete(:pending_mfa)
      session.delete(:mfa_user_id)
    end

    # Completes login after successful MFA verification.
    # Consumes the pending MFA session, logs in the user, and returns a result hash
    # with redirect information.
    #
    # @param user [User] the user to log in
    # @return [Hash] result with :status, :redirect_path, etc.
    def normalize_amr(token_kind_id)
      case token_kind_id.to_s
      when "email" then ["email_otp"]
      when "passkey" then ["passkey"]
      when "google" then ["google"]
      when "apple" then ["apple"]
      when "secret" then ["recovery_code"]
      else []
      end
    end

    def finalize_mfa_login!(user)
      return_to = pending_mfa&.dig(:return_to)
      clear_pending_mfa!

      result = log_in(user, require_totp_check: false)

      if result[:status] == :session_limit_hard_reject
        { status: :session_limit_hard_reject, message: result[:message], http_status: result[:http_status] }
      elsif result[:restricted]
        { status: :restricted, redirect_path: session_management_path }
      elsif result[:status] == :success
        { status: :success, redirect_path: return_to.presence }
      else
        result
      end
    end

    def session_management_path
      if respond_to?(:sign_app_in_session_path, true)
        sign_app_in_session_path
      elsif respond_to?(:sign_org_in_session_path, true)
        sign_org_in_session_path
      else
        "/sign/in/session"
      end
    rescue StandardError
      "/sign/in/session"
    end

    # Default redirect destination after login for guest_only! policy.
    # Override in controllers to customize (e.g. to preserve ri parameter).
    def after_login_path
      default_after_login_path
    end

    def default_after_login_path
      if respond_to?(:sign_app_root_path, true)
        sign_app_root_path
      elsif respond_to?(:sign_org_root_path, true)
        sign_org_root_path
      else
        "/"
      end
    rescue StandardError
      "/"
    end

    def session_limit_gate_return_to
      request&.fullpath.presence || request&.path.presence || "/"
    rescue StandardError
      "/"
    end

    def session_limit_gate_flow
      return "#{controller_path}.session" if respond_to?(:controller_path, true)

      "auth.#{resource_type}.session"
    rescue StandardError
      "auth.session"
    end

    def complete_sign_in_or_start_mfa!(resource, rt:, ri:, auth_method:, token_kind_id: "BROWSER_WEB",
                                       record_login_audit: true)
      auth_method = auth_method.to_s
      return log_in(
        resource, record_login_audit: record_login_audit, token_kind_id: token_kind_id,
                  require_totp_check: false,
      ) if mfa_bypassed_for_auth_method?(auth_method) || !mfa_required_for?(resource)

      return_to = resolve_mfa_return_to(rt)
      set_pending_mfa!(
        resource: resource, primary: auth_method, return_to: return_to, ri: ri,
        auth_method: auth_method,
      )

      {
        status: :mfa_required,
        redirect_path: mfa_entry_path(ri: ri),
        return_to: return_to,
      }
    end

    def check_login_cooldown!(resource)
      return unless Authentication::Base.login_cooldown_enabled

      fk =
        if resource.is_a?(::User)
          :user_id
        elsif resource.is_a?(::Customer)
          :customer_id
        else
          :staff_id
        end
      latest_at =
        if Rails.env.test?
          TokenRecord.connected_to(role: :writing) {
            token_class.where(fk => resource.id).order(created_at: :desc).pick(:created_at)
          }
        else
          TokenRecord.connected_to(role: :reading) {
            token_class.where(fk => resource.id).order(created_at: :desc).pick(:created_at)
          }
        end

      raise LoginCooldownError if latest_at && latest_at > LOGIN_COOLDOWN.ago
    end

    def render_login_cooldown
      render plain: LOGIN_COOLDOWN_MESSAGE, status: :too_many_requests
    end

    # Determine concurrent-session handling state for the resource.
    def session_limit_state_for(resource)
      max_sessions = max_sessions_for_resource(resource)
      active_count = count_active_sessions(resource)

      return :within_limit if active_count < max_sessions
      return :hard_reject if restricted_session_exists?(resource)

      :issue_restricted
    end

    # Returns the maximum allowed concurrent sessions for a resource
    def max_sessions_for_resource(resource)
      if resource.is_a?(::User)
        ::UserToken::MAX_SESSIONS_PER_USER
      elsif resource.is_a?(::Staff)
        ::StaffToken::MAX_SESSIONS_PER_STAFF
      elsif resource.is_a?(::Customer)
        ::CustomerToken::MAX_SESSIONS_PER_CUSTOMER
      else
        2 # Default fallback
      end
    end

    # Count active (non-revoked, non-restricted) sessions for a resource
    def count_active_sessions(resource)
      TokenRecord.connected_to(role: :writing) do
        if resource.is_a?(::User)
          ::UserToken.active_status.where(user_id: resource.id).count
        elsif resource.is_a?(::Staff)
          ::StaffToken.active_status.where(staff_id: resource.id).count
        elsif resource.is_a?(::Customer)
          ::CustomerToken.active_status.where(customer_id: resource.id).count
        else
          0
        end
      end
    end

    def restricted_session_exists?(resource)
      TokenRecord.connected_to(role: :writing) do
        scope = find_restricted_sessions_scope(resource)
        scope.present? && scope.exists?
      end
    end

    def find_restricted_sessions_scope(resource)
      if resource.is_a?(::User)
        ::UserToken.restricted_status.where(user_id: resource.id)
      elsif resource.is_a?(::Staff)
        ::StaffToken.restricted_status.where(staff_id: resource.id)
      elsif resource.is_a?(::Customer)
        ::CustomerToken.restricted_status.where(customer_id: resource.id)
      end
    end

    def restricted_session_expires_at
      ttl = token_class.const_defined?(:RESTRICTED_TTL) ? token_class::RESTRICTED_TTL : RESTRICTED_SESSION_TTL
      Time.current + ttl
    end

    def scheduled_login_token_attributes(now: Time.current)
      return {} unless %w(staff customer).include?(resource_type)

      ttl_class = (resource_type == "customer") ? CustomerToken : StaffToken
      lapses_at = now + ttl_class::LOGIN_SESSION_TTL
      {
        lapses_at: lapses_at,
        purge_at: lapses_at + ttl_class::DELETION_GRACE_PERIOD,
      }
    end

    # Store the pending login resource ID for session management
    def store_pending_login_resource(resource)
      if resource.is_a?(::User)
        session[:pending_login_user_id] = resource.id
      elsif resource.is_a?(::Staff)
        session[:pending_login_staff_id] = resource.id
      elsif resource.is_a?(::Customer)
        session[:pending_login_customer_id] = resource.id
      end
    end

    # ======================================================================
    # 8) Session/MFA helper reads + response shapers
    # ======================================================================
    # Get the current session token record
    def current_session
      return @current_session if defined?(@current_session)
      return nil unless current_session_public_id

      expiry_column = token_expiry_column(token_class)
      find_logic = -> { token_class.find_by(:public_id => current_session_public_id, expiry_column => nil) }

      @current_session =
        if Rails.env.test?
          # Ensure visibility by using writing connection which holds the test transaction
          TokenRecord.connected_to(role: :writing, &find_logic)
        else
          TokenRecord.connected_to(role: :reading, &find_logic)
        end
    end

    # Check if the current session is restricted
    def current_session_restricted?
      current_session&.restricted?
    end

    # Build a compact preference snapshot for inclusion in the auth JWT `prf` claim.
    # Uses the same key format as Preference::Base#build_preferences_payload:
    #   lx (language), ri (region), tz (timezone), ct (color theme)
    def build_auth_preference_snapshot(resource)
      pref = resolved_current_preference(resource) if respond_to?(:resolved_current_preference, true)
      pref ||= Current.preference
      return unless pref && !pref.null?

      {
        "lx" => pref.language,
        "ri" => pref.region,
        "tz" => pref.timezone,
        "ct" => pref.theme,
      }
    end

    # Re-issue the auth access token with current preference state.
    # Call after a preference change (language, theme, etc.) to keep the JWT in sync.
    def reissue_access_token!
      resource = current_resource
      return unless resource
      return unless current_session

      now = Time.current
      access_expires_at = access_token_expires_at_for(current_session, now: now)

      new_access_token = Token.encode(
        resource,
        host: request.host,
        session_public_id: current_session.public_id,
        resource_type: resource_type,
        expires_at: access_expires_at,
        preferences: build_auth_preference_snapshot(resource),
      )
      return unless new_access_token

      cookies[ACCESS_COOKIE_KEY] = cookie_options.merge(
        value: new_access_token,
        expires: access_expires_at,
      )
      Current.preference = resolved_current_preference(resource) if respond_to?(:resolved_current_preference, true)
    end

    def dbsc_payload_for(token_record)
      return unless token_record

      {
        binding_method: dbsc_binding_method_name(token_record),
        status: dbsc_status_name(token_record),
        session_id: token_record.dbsc_session_id,
        registration_url: token_dbsc_path,
        verification_url: token_dbsc_path,
      }
    end

    def dbsc_cookie_value_for(token_record)
      return unless token_record&.binding_method_dbsc?

      token_record.dbsc_session_id.presence
    end

    def dbsc_cookie_expires_at_for(token_record, now: Time.current)
      return unless token_record&.binding_method_dbsc?

      [now + DBSC_COOKIE_TTL, token_record.lapses_at].compact.min
    end

    def issue_dbsc_registration_header_for(token_record)
      return unless token_record
      return if token_record.binding_method_dbsc?

      challenge = issue_dbsc_challenge_for!(token_record)
      return if challenge.blank?

      response.set_header(
        Auth::IoKeys::Headers::DBSC_REGISTRATION,
        %((ES256 RS256);path="#{token_dbsc_path}";challenge="#{challenge}"),
      )
    end

    def issue_dbsc_challenge_for!(token_record)
      challenge = SecureRandom.urlsafe_base64(32)
      token_record.update!(dbsc_challenge: challenge, dbsc_challenge_issued_at: Time.current)
      challenge
    rescue StandardError
      nil
    end

    def token_dbsc_path
      case resource_type
      when "user"
        sign_app_edge_v0_token_dbsc_path
      when "staff"
        sign_org_edge_v0_token_dbsc_path
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

    def token_expiry_column(klass)
      return :expired_at if klass.column_names.include?("expired_at")
      return :lapses_at if klass.column_names.include?("lapses_at")
      return :revoked_at if klass.column_names.include?("revoked_at")

      raise ArgumentError, "#{klass.name} does not have expired_at/revoked_at column"
    end

    def access_token_expires_at_for(token_record, now: Time.current)
      [now + ACCESS_TOKEN_TTL, token_record_expiry_at(token_record)].compact.min
    end

    def refresh_cookie_expires_at_for(token_record)
      [token_record_expiry_at(token_record), token_record&.lapses_at].compact.min
    end

    def token_record_expiry_at(token_record)
      return unless token_record
      return token_record.revoked_at if token_record.respond_to?(:revoked_at)

      token_record.lapses_at if token_record.respond_to?(:lapses_at)
    end

    def expires_in_for(expires_at, now: Time.current)
      [(epoch_seconds(expires_at) - epoch_seconds(now)), 0].max
    end

    def epoch_seconds(value)
      return value.to_i if value.is_a?(Time) || value.is_a?(DateTime) || value.is_a?(ActiveSupport::TimeWithZone)
      return value.to_i if value.is_a?(ActiveSupport::Duration) || value.is_a?(Numeric)

      Integer(value.to_s, 10)
    rescue ArgumentError, TypeError
      0
    end

    def mfa_required_for?(resource)
      return false unless resource.is_a?(::User) || resource.is_a?(::Staff) || resource.is_a?(::Customer)
      return false unless resource.respond_to?(:multi_factor_enabled?)

      resource.multi_factor_enabled?
    end

    def mfa_bypassed_for_auth_method?(auth_method)
      %w(passkey social google apple).include?(auth_method.to_s)
    end

    def resolve_mfa_return_to(raw_value)
      return nil if raw_value.blank?

      decoded = decode_base64_urlsafe(raw_value)
      candidate = decoded.presence || raw_value

      safe_internal_path(candidate)
    end

    def decode_base64_urlsafe(value)
      Base64.urlsafe_decode64(value.to_s)
    rescue ArgumentError
      nil
    end

    def mfa_entry_path(ri: nil)
      if respond_to?(:sign_app_in_challenge_path, true)
        sign_app_in_challenge_path(ri: ri)
      elsif respond_to?(:sign_org_in_challenge_path, true)
        sign_org_in_challenge_path(ri: ri)
      else
        "/sign/in/challenge"
      end
    rescue StandardError
      "/sign/in/challenge"
    end

    def handle_auth_required_json(options)
      status = options[:status] || :unauthorized
      render json: { error: (options[:message] || "unauthorized") }, status: status
    end

    def handle_auth_required_html(options)
      path =
        if respond_to?(:sign_in_url_with_return, true)
          rt = Base64.urlsafe_encode64(request.original_url)
          sign_in_url_with_return(rt)
        elsif main_app.respond_to?(:sign_in_path)
          main_app.sign_in_path
        else
          "/sign/in"
        end
      message = options[:message] || I18n.t("errors.messages.login_required")
      redirect_to(path, allow_other_host: true, alert: message)
    end

    def handle_guest_only_json(options)
      status = options[:status] || :forbidden
      render json: { error: (options[:message] || "already_authenticated") }, status: status
    end

    def handle_guest_only_with_status_checks(options)
      if options[:status] == :unauthorized
        return render plain: (options[:message] || I18n.t("errors.messages.not_authorized")), status: :unauthorized
      end
      if options[:status] == :bad_request
        return render plain: (options[:message] || I18n.t("errors.messages.invalid_request")), status: :bad_request
      end

      handle_guest_only_html(options)
    end

    def handle_guest_only_html(options)
      path =
        if respond_to?(:after_login_path, true)
          after_login_path
        elsif main_app.respond_to?(:after_login_path)
          main_app.after_login_path
        else
          "/"
        end
      message = options[:message] || I18n.t("errors.messages.already_authenticated")
      redirect_to(path, allow_other_host: false, alert: message)
    end
  end
end
