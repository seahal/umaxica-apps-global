# typed: false
# frozen_string_literal: true

module OidcClientStoresStaticClientStore
  LOOPBACK_HOST_TOKENS = %w(localhost 127.0.0.1 ::1).freeze
  private_constant :LOOPBACK_HOST_TOKENS

  module_function

  def clients
    {
      # Sign credential gateway as RP. This is an RP client-auth key only; Sign remains non-OP.
      "sign-rp" => {
        redirect_uris: build_redirect_uris("SIGN_SERVICE_URL", "id.app.localhost") +
          build_redirect_uris("SIGN_STAFF_URL", "id.org.localhost") +
          build_redirect_uris("SIGN_CORPORATE_URL", "id.com.localhost"),
        post_logout_redirect_uris: build_post_logout_redirect_uris("SIGN_SERVICE_URL", "id.app.localhost") +
          build_post_logout_redirect_uris("SIGN_STAFF_URL", "id.org.localhost") +
          build_post_logout_redirect_uris("SIGN_CORPORATE_URL", "id.com.localhost"),
        backchannel_logout_uris: build_logout_uris("SIGN_SERVICE_URL", "id.app.localhost", "backchannel/logout") +
          build_logout_uris("SIGN_STAFF_URL", "id.org.localhost", "backchannel/logout") +
          build_logout_uris("SIGN_CORPORATE_URL", "id.com.localhost", "backchannel/logout"),
        backchannel_logout_session_required: true,
        aud: "sign-rp",
        resource_type: "client",
        name: "Sign RP",
        allowed_scopes: OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
        token_endpoint_auth_method: "private_key_jwt",
        jwt_namespace: "SIGN_APP",
      },
      # Historical name: this is Acme's own browser/local-session RP client.
      # It does not mean Base owns the Acme `/oidc/callback` endpoints.
      "base-rails-rp" => {
        redirect_uris: build_redirect_uris("ACME_SERVICE_URL", "www.app.localhost") +
          build_redirect_uris("ACME_STAFF_URL", "www.org.localhost") +
          build_redirect_uris("ACME_CORPORATE_URL", "www.com.localhost"),
        post_logout_redirect_uris: build_post_logout_redirect_uris("ACME_SERVICE_URL", "www.app.localhost") +
          build_post_logout_redirect_uris("ACME_STAFF_URL", "www.org.localhost") +
          build_post_logout_redirect_uris("ACME_CORPORATE_URL", "www.com.localhost"),
        aud: "base-rails-rp",
        resource_type: "client",
        name: "Base Rails RP",
        allowed_scopes: OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
        token_endpoint_auth_method: "private_key_jwt",
        jwt_namespace: "ACME_APP",
      },
      # Core browser RP.
      "core-next-rp" => {
        redirect_uris: build_redirect_uris("CORE_SERVICE_URL", "www-jp.umaxica.app") +
          build_redirect_uris("CORE_STAFF_URL", "www-jp.umaxica.org") +
          build_redirect_uris("CORE_CORPORATE_URL", "www-jp.umaxica.com"),
        post_logout_redirect_uris: build_post_logout_redirect_uris("CORE_SERVICE_URL", "www-jp.umaxica.app") +
          build_post_logout_redirect_uris("CORE_STAFF_URL", "www-jp.umaxica.org") +
          build_post_logout_redirect_uris("CORE_CORPORATE_URL", "www-jp.umaxica.com"),
        backchannel_logout_uris: build_logout_uris("CORE_SERVICE_URL", "www-jp.umaxica.app", "backchannel/logout") +
          build_logout_uris("CORE_STAFF_URL", "www-jp.umaxica.org", "backchannel/logout") +
          build_logout_uris("CORE_CORPORATE_URL", "www-jp.umaxica.com", "backchannel/logout"),
        backchannel_logout_session_required: true,
        aud: "core-next-rp",
        resource_type: "client",
        name: "Core Next RP",
        allowed_scopes: OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
        token_endpoint_auth_method: "private_key_jwt",
        jwt_namespace: "CORE_APP",
      },
      "app-ios-rp" => {
        redirect_uris: ["umaxica://oidc/callback"],
        aud: "palm-api",
        resource_type: "client",
        name: "App iOS RP",
        allowed_scopes: OidcClientRegistry::PALM_ALLOWED_SCOPES,
        token_endpoint_auth_method: "none",
      },
      "app-android-rp" => {
        redirect_uris: ["com.umaxica.app:/oidc/callback"],
        aud: "palm-api",
        resource_type: "client",
        name: "App Android RP",
        allowed_scopes: OidcClientRegistry::PALM_ALLOWED_SCOPES,
        token_endpoint_auth_method: "none",
      },
      # Docs
      "docs_app" => {
        redirect_uris: build_redirect_uris("DOCS_SERVICE_URL", "docs.app.localhost"),
        aud: "umaxica-docs-app",
        resource_type: "client",
        name: "Docs App",
        allowed_scopes: OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      },
      "docs_org" => {
        redirect_uris: build_redirect_uris("DOCS_STAFF_URL", "docs.org.localhost"),
        aud: "umaxica-docs-org",
        resource_type: "operator",
        name: "Docs Org",
        allowed_scopes: OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      },
      "docs_com" => {
        redirect_uris: build_redirect_uris("DOCS_CORPORATE_URL", "docs.com.localhost"),
        aud: "umaxica-docs-com",
        resource_type: "visitor",
        name: "Docs Com",
        allowed_scopes: OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      },
      # News
      "news_app" => {
        redirect_uris: build_redirect_uris("NEWS_SERVICE_URL", "news.app.localhost"),
        aud: "umaxica-news-app",
        resource_type: "client",
        name: "News App",
        allowed_scopes: OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      },
      "news_org" => {
        redirect_uris: build_redirect_uris("NEWS_STAFF_URL", "news.org.localhost"),
        aud: "umaxica-news-org",
        resource_type: "operator",
        name: "News Org",
        allowed_scopes: OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      },
      "news_com" => {
        redirect_uris: build_redirect_uris("NEWS_CORPORATE_URL", "news.com.localhost"),
        aud: "umaxica-news-com",
        resource_type: "visitor",
        name: "News Com",
        allowed_scopes: OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      },
      # Help
      "help_app" => {
        redirect_uris: build_redirect_uris("HELP_SERVICE_URL", "help.app.localhost"),
        aud: "umaxica-help-app",
        resource_type: "client",
        name: "Help App",
        allowed_scopes: OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      },
      "help_org" => {
        redirect_uris: build_redirect_uris("HELP_STAFF_URL", "help.org.localhost"),
        aud: "umaxica-help-org",
        resource_type: "operator",
        name: "Help Org",
        allowed_scopes: OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      },
      "help_com" => {
        redirect_uris: build_redirect_uris("HELP_CORPORATE_URL", "help.com.localhost"),
        aud: "umaxica-help-com",
        resource_type: "visitor",
        name: "Help Com",
        allowed_scopes: OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      },
    }.freeze
  end

  def build_redirect_uris(env_key, default_host)
    host = boot_host_for(env_key, default_host)
    protocol = (Rails.env.production? || public_host?(host)) ? "https" : "http"
    port_suffix = (Rails.env.production? || public_host?(host)) ? "" : ":3000"
    ["#{protocol}://#{host}#{port_suffix}/oidc/callback"]
  end

  def build_post_logout_redirect_uris(env_key, default_host)
    host = boot_host_for(env_key, default_host)
    protocol = (Rails.env.production? || public_host?(host)) ? "https" : "http"
    port_suffix = (Rails.env.production? || public_host?(host)) ? "" : ":3000"
    ["#{protocol}://#{host}#{port_suffix}/sign/out/complete"]
  end

  def build_logout_uris(env_key, default_host, endpoint)
    host = boot_host_for(env_key, default_host)
    protocol = (Rails.env.production? || public_host?(host)) ? "https" : "http"
    port_suffix = (Rails.env.production? || public_host?(host)) ? "" : ":3000"
    ["#{protocol}://#{host}#{port_suffix}/oidc/#{endpoint}"]
  end

  def public_host?(host)
    normalized_host = URI.parse("//#{host}").host.to_s

    normalized_host.present? &&
      LOOPBACK_HOST_TOKENS.none? { |token| normalized_host.include?(token) }
  rescue URI::InvalidURIError
    false
  end

  def boot_host_for(env_key, default_host)
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    host =
      case env_key
      when "SIGN_SERVICE_URL" then hosts.sign_service.to_s
      when "SIGN_STAFF_URL" then hosts.sign_staff.to_s
      when "SIGN_CORPORATE_URL" then hosts.sign_corporate.to_s
      when "ACME_SERVICE_URL" then hosts.acme_service.to_s
      when "ACME_STAFF_URL" then hosts.acme_staff.to_s
      when "ACME_CORPORATE_URL" then hosts.acme_corporate.to_s
      when "CORE_SERVICE_URL" then hosts.core_service.to_s
      when "CORE_STAFF_URL" then hosts.core_staff.to_s
      when "CORE_CORPORATE_URL" then hosts.core_corporate.to_s
      else default_host
      end

    normalize_host(host)
  end

  def normalize_host(host)
    parsed_host = URI.parse(host.to_s).host if host.to_s.include?("://")
    parsed_host.presence || URI.parse("//#{host}").host.to_s.presence || host.to_s
  rescue URI::InvalidURIError
    host.to_s
  end

  private_class_method :build_redirect_uris, :build_post_logout_redirect_uris, :build_logout_uris,
                       :public_host?, :boot_host_for, :normalize_host
end
