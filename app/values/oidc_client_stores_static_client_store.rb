# typed: false
# frozen_string_literal: true

module OidcClientStoresStaticClientStore
  LOOPBACK_HOST_TOKENS = %w(localhost 127.0.0.1 ::1).freeze
  private_constant :LOOPBACK_HOST_TOKENS

  module_function

  def clients
    {
      # Sign credential gateway as RP. This is an RP client-auth key only; Sign remains non-OP.
      #
      # Each realm registers both its public (browser-visible) and private (pod-internal) auth host.
      # OidcSsoInitiator#oidc_callback_url matches a registered redirect URI against request.host,
      # and the Auth surfaces are routed on both variants, so registering only one variant makes the
      # other host fail with "OIDC redirect URI is not registered for this host".
      "sign-rp" => {
        redirect_uris_by_realm: {
          "client" => build_redirect_uris("PUBLIC_AUTH_SERVICE_URL") +
            build_redirect_uris("PRIVATE_AUTH_SERVICE_URL"),
          "operator" => build_redirect_uris("PUBLIC_AUTH_STAFF_URL") +
            build_redirect_uris("PRIVATE_AUTH_STAFF_URL"),
          "visitor" => build_redirect_uris("PUBLIC_AUTH_CORPORATE_URL") +
            build_redirect_uris("PRIVATE_AUTH_CORPORATE_URL"),
        },
        post_logout_redirect_uris: build_post_logout_redirect_uris("PUBLIC_AUTH_SERVICE_URL") +
          build_post_logout_redirect_uris("PRIVATE_AUTH_SERVICE_URL") +
          build_post_logout_redirect_uris("PUBLIC_AUTH_STAFF_URL") +
          build_post_logout_redirect_uris("PRIVATE_AUTH_STAFF_URL") +
          build_post_logout_redirect_uris("PUBLIC_AUTH_CORPORATE_URL") +
          build_post_logout_redirect_uris("PRIVATE_AUTH_CORPORATE_URL"),
        backchannel_logout_uris: build_logout_uris("PUBLIC_AUTH_SERVICE_URL", "backchannel/logout") +
          build_logout_uris("PRIVATE_AUTH_SERVICE_URL", "backchannel/logout") +
          build_logout_uris("PUBLIC_AUTH_STAFF_URL", "backchannel/logout") +
          build_logout_uris("PRIVATE_AUTH_STAFF_URL", "backchannel/logout") +
          build_logout_uris("PUBLIC_AUTH_CORPORATE_URL", "backchannel/logout") +
          build_logout_uris("PRIVATE_AUTH_CORPORATE_URL", "backchannel/logout"),
        backchannel_logout_session_required: true,
        aud: "sign-rp",
        resource_type: "client",
        name: "Sign RP",
        allowed_scopes: OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
        token_endpoint_auth_method: "private_key_jwt",
        jwt_namespace: "SIGN_APP",
      },
      # Shared browser RP client for Base's local browser flow and launcher flows.
      "base-rails-rp" => {
        redirect_uris_by_realm: {
          "client" => build_redirect_uris("BASE_SERVICE_URL", "www.app.localhost") +
            build_redirect_uris("SIDE_SERVICE_URL", "side.app.localhost"),
          "operator" => build_redirect_uris("BASE_STAFF_URL", "www.org.localhost") +
            build_redirect_uris("SIDE_STAFF_URL", "side.org.localhost"),
          "visitor" => build_redirect_uris("BASE_CORPORATE_URL", "www.com.localhost") +
            build_redirect_uris("SIDE_CORPORATE_URL", "side.com.localhost"),
        },
        post_logout_redirect_uris: build_post_logout_redirect_uris("BASE_SERVICE_URL", "www.app.localhost") +
          build_post_logout_redirect_uris("BASE_STAFF_URL", "www.org.localhost") +
          build_post_logout_redirect_uris("BASE_CORPORATE_URL", "www.com.localhost") +
          build_post_logout_redirect_uris("SIDE_SERVICE_URL", "side.app.localhost") +
          build_post_logout_redirect_uris("SIDE_STAFF_URL", "side.org.localhost") +
          build_post_logout_redirect_uris("SIDE_CORPORATE_URL", "side.com.localhost"),
        aud: "base-rails-rp",
        resource_type: "client",
        name: "Base Rails RP",
        allowed_scopes: OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
        token_endpoint_auth_method: "private_key_jwt",
        jwt_namespace: "BASE_APP",
      },
      # Side browser RP.
      "side-rails-rp" => {
        redirect_uris_by_realm: {
          "client" => build_redirect_uris("SIDE_SERVICE_URL", "side.app.localhost"),
          "operator" => build_redirect_uris("SIDE_STAFF_URL", "side.org.localhost"),
          "visitor" => build_redirect_uris("SIDE_CORPORATE_URL", "side.com.localhost"),
        },
        post_logout_redirect_uris: build_post_logout_redirect_uris("SIDE_SERVICE_URL", "side.app.localhost") +
          build_post_logout_redirect_uris("SIDE_STAFF_URL", "side.org.localhost") +
          build_post_logout_redirect_uris("SIDE_CORPORATE_URL", "side.com.localhost"),
        backchannel_logout_uris: build_logout_uris("SIDE_SERVICE_URL", "backchannel/logout", "side.app.localhost") +
          build_logout_uris("SIDE_STAFF_URL", "backchannel/logout", "side.org.localhost") +
          build_logout_uris("SIDE_CORPORATE_URL", "backchannel/logout", "side.com.localhost"),
        backchannel_logout_session_required: true,
        aud: "side-rails-rp",
        resource_type: "client",
        name: "Side Rails RP",
        allowed_scopes: OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
        token_endpoint_auth_method: "private_key_jwt",
        jwt_namespace: "BASE_APP",
      },
      # Core browser RP.
      "core-next-rp" => {
        redirect_uris_by_realm: {
          "client" => build_redirect_uris("PUBLIC_CORE_SERVICE_URL", "jpx.umaxica.app"),
          "operator" => build_redirect_uris("PUBLIC_CORE_STAFF_URL", "jpx.umaxica.org"),
          "visitor" => build_redirect_uris("PUBLIC_CORE_CORPORATE_URL", "jpx.umaxica.com"),
        },
        post_logout_redirect_uris: build_post_logout_redirect_uris("PUBLIC_CORE_SERVICE_URL", "jpx.umaxica.app") +
          build_post_logout_redirect_uris("PUBLIC_CORE_STAFF_URL", "jpx.umaxica.org") +
          build_post_logout_redirect_uris("PUBLIC_CORE_CORPORATE_URL", "jpx.umaxica.com"),
        backchannel_logout_uris: build_logout_uris(
          "PUBLIC_CORE_SERVICE_URL", "backchannel/logout", "jpx.umaxica.app",
        ) +
          build_logout_uris("PUBLIC_CORE_STAFF_URL", "backchannel/logout", "jpx.umaxica.org") +
          build_logout_uris("PUBLIC_CORE_CORPORATE_URL", "backchannel/logout", "jpx.umaxica.com"),
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

  # default_host is only consulted for env keys boot_host_for does not map; keys it maps resolve
  # from boot config and must not carry a literal default that can drift from the real host.
  def build_redirect_uris(env_key, default_host = nil)
    configured_hosts_for(env_key, default_host).map do |host|
      protocol = (Rails.env.production? || public_host?(host)) ? "https" : "http"
      port_suffix = (Rails.env.production? || public_host?(host)) ? "" : ":3000"
      "#{protocol}://#{host}#{port_suffix}/oidc/callback"
    end
  end

  def build_post_logout_redirect_uris(env_key, default_host = nil)
    configured_hosts_for(env_key, default_host).map do |host|
      protocol = (Rails.env.production? || public_host?(host)) ? "https" : "http"
      port_suffix = (Rails.env.production? || public_host?(host)) ? "" : ":3000"
      "#{protocol}://#{host}#{port_suffix}/sign/out/complete"
    end
  end

  def build_logout_uris(env_key, endpoint, default_host = nil)
    configured_hosts_for(env_key, default_host).map do |host|
      protocol = (Rails.env.production? || public_host?(host)) ? "https" : "http"
      port_suffix = (Rails.env.production? || public_host?(host)) ? "" : ":3000"
      "#{protocol}://#{host}#{port_suffix}/oidc/#{endpoint}"
    end
  end

  def public_host?(host)
    normalized_host = URI.parse("//#{host}").host.to_s

    normalized_host.present? &&
      LOOPBACK_HOST_TOKENS.none? { |token| normalized_host.include?(token) }
  rescue URI::InvalidURIError
    false
  end

  def configured_hosts_for(env_key, default_host = nil)
    hosts = [
      ENV.fetch(env_key, nil).presence,
      boot_host_for(env_key, default_host),
    ].compact
    hosts.map! { |host| normalize_host(host) }
    hosts.uniq!
    hosts
  end

  def boot_host_for(env_key, default_host = nil)
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    host =
      case env_key
      when "PUBLIC_AUTH_SERVICE_URL", "PRIVATE_AUTH_SERVICE_URL" then hosts.sign_service.to_s
      when "PUBLIC_AUTH_STAFF_URL", "PRIVATE_AUTH_STAFF_URL" then hosts.sign_staff.to_s
      when "PUBLIC_AUTH_CORPORATE_URL", "PRIVATE_AUTH_CORPORATE_URL" then hosts.sign_corporate.to_s
      when "BASE_SERVICE_URL" then hosts.base_service.to_s
      when "BASE_STAFF_URL" then hosts.base_staff.to_s
      when "BASE_CORPORATE_URL" then hosts.base_corporate.to_s
      when "SIDE_SERVICE_URL" then hosts.side_service.to_s
      when "SIDE_STAFF_URL" then hosts.side_staff.to_s
      when "SIDE_CORPORATE_URL" then hosts.side_corporate.to_s
      when "CORE_SERVICE_URL" then hosts.core_service.to_s
      when "CORE_STAFF_URL" then hosts.core_staff.to_s
      when "CORE_CORPORATE_URL" then hosts.core_corporate.to_s
      else
        raise KeyError, "No boot host mapping for #{env_key} and no default host given" if default_host.blank?

        default_host
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
                       :public_host?, :configured_hosts_for, :boot_host_for, :normalize_host
end
