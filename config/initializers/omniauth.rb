# typed: false
# frozen_string_literal: true

# =============================================================================
# OmniAuth Configuration
# =============================================================================
#
# Supported providers:
# - Google OAuth2: Standard OAuth2 flow with state parameter
# - Apple Sign In: Uses id_token (OIDC), POST callback
#
# Routing (OmniAuth standard):
# - Start:    POST /auth/:provider (CSRF protected via omniauth-rails_csrf_protection)
# - Callback: GET/POST /auth/:provider/callback
# - Failure:  GET/POST /auth/failure
#
# Our custom entry point:
# - GET /social/start?provider=...&intent=... -> prepares intent, redirects to /auth/:provider
#
# State Parameter:
# - All providers use state validation (via SocialAuthConcern)
# - State is stored in session[:social_auth_intent] and validated on callback
# - Apple receives state via POST body (form_post response_mode)
#
# IMPORTANT: Apple Sign In Constraints
# - Callback URL must be HTTPS with a valid domain (no localhost/IP)
# - Local development requires a tunnel (ngrok, Cloudflare Tunnel, etc.)
# - Register exactly: https://<your-domain>/auth/apple/callback in Apple Developer
# - Callback is always POST (form_post response mode)
#
# IMPORTANT: Google Cloud Console Setup
# - App client: register /auth/google_app/callback
# - Org client: register /auth/google_org/callback
#
# =============================================================================

# Load credentials early
# App (user) Google credentials
google_app_client_id = Rails.app.creds.option(:OMNI_AUTH_GOOGLE_APP_CLIENT_ID)
google_app_client_secret = Rails.app.creds.option(:OMNI_AUTH_GOOGLE_APP_CLIENT_SECRET)
# Org (staff) Google credentials - separate OAuth client for staff domain
google_org_client_id = Rails.app.creds.option(:OMNI_AUTH_GOOGLE_ORG_CLIENT_ID)
google_org_client_secret = Rails.app.creds.option(:OMNI_AUTH_GOOGLE_ORG_CLIENT_SECRET)

apple_client_id = Rails.app.creds.option(:OMNI_AUTH_APPLE_CLIENT_ID)
apple_team_id = Rails.app.creds.option(:OMNI_AUTH_APPLE_TEAM_ID)
apple_key_id = Rails.app.creds.option(:OMNI_AUTH_APPLE_KEY_ID)
apple_pem = Rails.app.creds.option(:OMNI_AUTH_APPLE_PRIVATE_KEY)

# =============================================================================
# Corporate Social Login Guard
# =============================================================================
# Rejects /auth/... requests on the corporate host to prevent social login bypass.
class OmniAuthCorporateGuard
  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) unless env["PATH_INFO"].start_with?("/auth/")

    if corporate_host?(env)
      return [404, { "Content-Type" => "text/plain" }, ["Not Found"]]
    end

    @app.call(env)
  end

  private

  def corporate_host?(env)
    # ENV["ID_CORPORATE_URL"] is hostname-only (e.g. id.com.localhost or id.umaxica.com)
    corporate = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    Rack::Request.new(env).host == corporate
  end
end

Rails.application.config.middleware.use(OmniAuthCorporateGuard)
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
  # Google OAuth2 - Org (staff sign-in only)
  # ---------------------------------------------------------------------------
  # Callback: GET /auth/google_org/callback
  provider :google_oauth2,
           google_org_client_id,
           google_org_client_secret,
           {
             name: "google_org",
             callback_path: "/auth/google_org/callback",
             scope: "openid",
             access_type: "offline",
             prompt: "select_account",
           }

  # ---------------------------------------------------------------------------
  # Apple Sign In
  # ---------------------------------------------------------------------------
  # Uses OIDC id_token flow. Callback: POST /auth/apple/callback
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
             # Apple's form_post callback is a cross-site POST from appleid.apple.com.
             # SameSite=Lax session cookies are NOT sent on cross-site POSTs, so the
             # OmniAuth state stored in session is lost. Skip OmniAuth's state check
             # Apple's signed id_token (verified via JWKS) already provides CSRF protection.
             provider_ignores_state: true,
             authorize_params: {
               response_mode: "query",
               response_type: "code",
             },
           }
end

# Allow both GET and POST for initiating OAuth
# - GET: Used by our custom /social/start entry point (CSRF protected by state validation)
# - POST: Traditional form submission (CSRF protected by Rails token)
# State validation in SocialAuthConcern provides CSRF protection for both methods
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
