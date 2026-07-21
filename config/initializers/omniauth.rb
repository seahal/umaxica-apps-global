# typed: false
# frozen_string_literal: true

# =============================================================================
# OmniAuth Configuration
# =============================================================================
#
# Supported providers:
# - Google OAuth2: Standard OAuth2 flow with state parameter
# - Apple Sign In: Uses OIDC code flow with query response mode
#
# Routing (OmniAuth standard):
# - Start:    POST /social/google, POST /social/apple (CSRF protected via omniauth-rails_csrf_protection)
# - Callback: GET /social/google/callback, GET /social/apple/callback
# - Failure:  GET /social/failure
#
# Our custom entry point:
# - GET /social/:provider/sign/in and /social/:provider/sign/up -> prepares intent, redirects to provider callback
#
# State Parameter:
# - SocialCallbackGuard validates callback state through CallbackStateStore for all app providers.
# - SocialAuth stores intent context; provider callback CSRF protection is not solely owned
#   by that concern.
# - Apple provider_ignores_state disables provider-side state handling only; app-side
#   CallbackStateStore/SocialCallbackGuard validation still runs.
#
# IMPORTANT: Apple Sign In Constraints
# - Callback URL must be HTTPS with a valid domain (no localhost/IP)
# - Local development requires a tunnel (ngrok, Cloudflare Tunnel, etc.)
# - Register exactly: https://<your-domain>/social/apple/callback in Apple Developer
# - Callback uses GET because response_mode is query.
#
# IMPORTANT: Google Cloud Console Setup
# - App client: register /social/google/callback
#
# =============================================================================

# Load credentials early
# App (user) Google credentials
google_client_id = Rails.app.creds.option(:OMNI_AUTH_GOOGLE_APP_CLIENT_ID)
google_client_secret = Rails.app.creds.option(:OMNI_AUTH_GOOGLE_APP_CLIENT_SECRET)
apple_client_id = Rails.app.creds.option(:OMNI_AUTH_APPLE_CLIENT_ID)
apple_team_id = Rails.app.creds.option(:OMNI_AUTH_APPLE_TEAM_ID)
apple_key_id = Rails.app.creds.option(:OMNI_AUTH_APPLE_KEY_ID)
apple_pem = Rails.app.creds.option(:OMNI_AUTH_APPLE_PRIVATE_KEY)

module OmniAuthCallbackOrigin
  module_function

  def call(env)
    request = Rack::Request.new(env)
    scheme = public_sign_host?(request.host) ? "https" : request.scheme

    "#{scheme}://#{request.host_with_port}"
  end

  # Compared against request.host (a bare hostname). Use OriginValue#host, not #to_s
  # which is a full "https://..." origin and would never match.
  PUBLIC_SIGN_HOSTS =
    [
      Rails.configuration.x.boot_config.fetch(:hosts).sign_service.host,
      Rails.configuration.x.boot_config.fetch(:hosts).sign_staff.host,
    ].map(&:downcase).freeze

  def public_sign_host?(host)
    public_sign_hosts.include?(host.to_s.downcase)
  end

  def public_sign_hosts
    PUBLIC_SIGN_HOSTS
  end
end

OmniAuth.config.full_host = ->(env) { OmniAuthCallbackOrigin.call(env) }
OmniAuth.config.path_prefix = "/social"

# =============================================================================
# Non-App Social Login Guard
# =============================================================================
# Rejects /social/... requests on non-app sign hosts to prevent social login bypass.
class OmniAuthNonAppSocialGuard
  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) unless env["PATH_INFO"].start_with?("/social/")

    if blocked_host?(env)
      return [404, { "Content-Type" => "text/plain" }, ["Not Found"]]
    end

    @app.call(env)
  end

  private

  def blocked_host?(env)
    boot_hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    blocked_hosts = [
      boot_hosts.sign_corporate.host,
      boot_hosts.sign_staff.host,
      boot_hosts.auth_corporate.host,
      boot_hosts.auth_staff.host,
      boot_hosts.base_corporate.host,
      boot_hosts.base_staff.host,
    ] + %w(
      PUBLIC_AUTH_CORPORATE_URL
      PRIVATE_AUTH_CORPORATE_URL
      PUBLIC_AUTH_STAFF_URL
      PRIVATE_AUTH_STAFF_URL
      PUBLIC_BASE_CORPORATE_URL
      PRIVATE_BASE_CORPORATE_URL
      PUBLIC_BASE_STAFF_URL
      PRIVATE_BASE_STAFF_URL
    ).filter_map { |key| ENV.fetch(key, nil).presence }
    blocked_hosts.include?(Rack::Request.new(env).host)
  end
end

class OmniAuthSocialOriginSanitizer
  AUTH_PATH_PREFIXES = %w(/social/google /social/apple).freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    if auth_request_path?(env["PATH_INFO"])
      env.delete("HTTP_REFERER")
    end

    @app.call(env)
  end

  private

  def auth_request_path?(path)
    AUTH_PATH_PREFIXES.any? { |prefix| path.to_s.start_with?(prefix) }
  end
end

Rails.application.config.middleware.use(OmniAuthSocialOriginSanitizer)
Rails.application.config.middleware.use(OmniAuthNonAppSocialGuard)
Rails.application.config.middleware.use(OmniAuth::Builder) do
  # ---------------------------------------------------------------------------
  # Google OAuth2 - App (user sign-in/sign-up)
  # ---------------------------------------------------------------------------
  # Callback: GET /social/google/callback
  provider :google_oauth2,
           google_client_id,
           google_client_secret,
           {
             name: "google",
             callback_path: "/social/google/callback",
             scope: "openid",
             access_type: "offline",
             prompt: "select_account",
           }

  # ---------------------------------------------------------------------------
  # Apple Sign In
  # ---------------------------------------------------------------------------
  # Uses OIDC code flow. Callback: GET /social/apple/callback
  #
  # Required credentials:
  # - CLIENT_ID: Service ID (e.g., "com.example.app.web")
  # - TEAM_ID: Apple Developer Team ID (10 chars)
  # - KEY_ID: Key ID from Apple Developer (10 chars)
  # - PRIVATE_KEY: Contents of .p8 file (including BEGIN/END markers)
  provider :apple,
           apple_client_id,
           "", # Secret is derived from private key, not passed here
           {
             # OmniAuth standard callback path
             callback_path: "/social/apple/callback",
             # IMPORTANT: We authenticate by provider+uid only, NOT email
             # Empty scope means we only get the user identifier (sub claim in id_token)
             scope: "",
             team_id: apple_team_id,
             key_id: apple_key_id,
             pem: apple_pem,
             # Required: omniauth-apple's client_id method returns nil during callback
             # unless the aud from id_token is listed in authorized_client_ids
             authorized_client_ids: [apple_client_id],
             # The app validates its own social state in the callback controller.
             provider_ignores_state: true,
             authorize_params: {
               response_mode: "query",
               response_type: "code",
             },
           }
end

# Allow both GET and POST for initiating OAuth
# - GET: Used after our custom /social/:provider/sign/in entry point redirects to OmniAuth
# - POST: Traditional form submission (CSRF protected by Rails token)
# Callback state validation is enforced by SocialCallbackGuard and CallbackStateStore.
OmniAuth.config.silence_get_warning = true
OmniAuth.config.allowed_request_methods = %i(get post)
OmniAuth.config.after_request_phase = proc { |env| SocialCallbackGuard.capture_request_state!(env) }

# =============================================================================
# Failure Handling
# =============================================================================
# Redirect to our custom failure endpoint.
# This uses OmniAuth standard path: /social/failure
OmniAuth.config.on_failure =
  proc do |env|
    request = Rack::Request.new(env)
    message = env["omniauth.error.type"]&.to_s || "unknown_error"
    strategy = env["omniauth.error.strategy"]&.name || "unknown"

    # Provider exception messages can contain response bodies or credentials;
    # retain only allowlisted classification metadata.
    error = env["omniauth.error"]
    if error
      Rails.logger.error(
        JitLogEvent.format(
          "social_auth.failure",
          strategy: strategy,
          type: message,
          error_class: error.class.name,
        ),
      )
    end

    if strategy == "apple"
      Rails.logger.info(
        JitLogEvent.format(
          "social_auth.apple.nonce_failure_context",
          request_path: request.path,
          request_method: request.request_method,
          strategy_has_value: request.session["omniauth.nonce"].present?,
          app_has_value: request.session[:social_auth_nonce].present?,
          message: message,
        ),
      )
    end

    # Build failure URL with query parameters (OmniAuth standard path)
    failure_path = "/social/failure?message=#{CGI.escape(message)}&strategy=#{CGI.escape(strategy)}"

    Rack::Response.new(["302 Found"], 302, "Location" => failure_path).finish
  end
