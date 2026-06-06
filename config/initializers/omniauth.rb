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
# - Start:    POST /auth/:provider (CSRF protected via omniauth-rails_csrf_protection)
# - Callback: GET /auth/google_app/callback, GET /auth/apple/callback
# - Failure:  GET /auth/failure
#
# Our custom entry point:
# - POST /social/auth/:provider/continue?intent=... -> prepares intent, redirects to /auth/:provider
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
# - Register exactly: https://<your-domain>/auth/apple/callback in Apple Developer
# - Callback uses GET because response_mode is query.
#
# IMPORTANT: Google Cloud Console Setup
# - App client: register /auth/google_app/callback
#
# =============================================================================

# Load credentials early
# App (user) Google credentials
google_app_client_id = Rails.app.creds.option(:OMNI_AUTH_GOOGLE_APP_CLIENT_ID)
google_app_client_secret = Rails.app.creds.option(:OMNI_AUTH_GOOGLE_APP_CLIENT_SECRET)
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

  PUBLIC_SIGN_HOSTS = %w(ID_SERVICE_URL SIGN_SERVICE_URL ID_STAFF_URL SIGN_STAFF_URL).filter_map do |key|
    ENV[key].to_s.downcase.presence
  end.freeze

  def public_sign_host?(host)
    public_sign_hosts.include?(host.to_s.downcase)
  end

  def public_sign_hosts
    PUBLIC_SIGN_HOSTS
  end
end

OmniAuth.config.full_host = ->(env) { OmniAuthCallbackOrigin.call(env) }

# =============================================================================
# Non-App Social Login Guard
# =============================================================================
# Rejects /auth/... requests on non-app sign hosts to prevent social login bypass.
class OmniAuthNonAppSocialGuard
  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) unless env["PATH_INFO"].start_with?("/auth/")

    if blocked_host?(env)
      return [404, { "Content-Type" => "text/plain" }, ["Not Found"]]
    end

    @app.call(env)
  end

  private

  def blocked_host?(env)
    blocked_hosts = [
      ENV.fetch("ID_CORPORATE_URL", "id.com.localhost"),
      ENV.fetch("ID_STAFF_URL", "id.org.localhost"),
    ]
    blocked_hosts.include?(Rack::Request.new(env).host)
  end
end

Rails.application.config.middleware.use(OmniAuthNonAppSocialGuard)
Rails.application.config.middleware.use(OmniAuth::Builder) do
  # ---------------------------------------------------------------------------
  # Google OAuth2 - App (user sign-in/sign-up)
  # ---------------------------------------------------------------------------
  # Callback: GET /auth/google_app/callback
  provider :google_oauth2,
           google_app_client_id,
           google_app_client_secret,
           {
             name: "google_app",
             callback_path: "/auth/google_app/callback",
             scope: "openid",
             access_type: "offline",
             prompt: "select_account",
           }

  # ---------------------------------------------------------------------------
  # Apple Sign In
  # ---------------------------------------------------------------------------
  # Uses OIDC code flow. Callback: GET /auth/apple/callback
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
             callback_path: "/auth/apple/callback",
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
# - GET: Used after our custom /social/auth/:provider/continue entry point redirects to OmniAuth
# - POST: Traditional form submission (CSRF protected by Rails token)
# Callback state validation is enforced by SocialCallbackGuard and CallbackStateStore.
OmniAuth.config.silence_get_warning = true
OmniAuth.config.allowed_request_methods = %i(get post)
OmniAuth.config.after_request_phase = proc { |env| SocialCallbackGuard.capture_request_state!(env) }

# =============================================================================
# Failure Handling
# =============================================================================
# Redirect to our custom failure endpoint.
# This uses OmniAuth standard path: /auth/failure
OmniAuth.config.on_failure =
  proc do |env|
    message = env["omniauth.error.type"]&.to_s || "unknown_error"
    strategy = env["omniauth.error.strategy"]&.name || "unknown"

    # Log the actual error for debugging (not exposed to user)
    error = env["omniauth.error"]
    if error
      Rails.logger.error(
        "[OmniAuth] Failure: strategy=#{strategy} type=#{message} " \
        "error_class=#{error.class.name} error_message=#{error.message}",
      )
    end

    # Build failure URL with query parameters (OmniAuth standard path)
    failure_path = "/auth/failure?message=#{CGI.escape(message)}&strategy=#{CGI.escape(strategy)}"

    Rack::Response.new(["302 Found"], 302, "Location" => failure_path).finish
  end
