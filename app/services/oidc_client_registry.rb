# typed: false
# frozen_string_literal: true

require "concurrent"

module OidcClientRegistry
  class ClientNotFound < StandardError; end

  class InvalidRedirectUri < StandardError; end

  VisitorAccount =
    Data.define(
      :client_id, :client_secret, :redirect_uris, :post_logout_redirect_uris, :aud, :resource_type,
      :name, :domains, :registered_token_endpoint_auth_method,
      :metadata_token_endpoint_auth_method, :jwt_namespace, :backchannel_logout_uris,
      :backchannel_logout_session_required,
    ) do
      def public_client?
        registered_token_endpoint_auth_method == "none"
      end

      def confidential_client?
        !public_client?
      end

      def private_key_jwt_client?
        registered_token_endpoint_auth_method == "private_key_jwt"
      end
    end
  CLIENTS_MUTEX = Mutex.new
  CLIENTS_CACHE = Concurrent::AtomicReference.new(nil)

  LOOPBACK_HOST_TOKENS = %w(localhost 127.0.0.1 ::1).freeze
  private_constant :LOOPBACK_HOST_TOKENS

  module_function

  # @param client_id [String]
  # @return [VisitorAccount, nil]
  def find(client_id)
    config = clients[client_id.to_s]
    return nil unless config

    registered_auth_method = config[:token_endpoint_auth_method]

    VisitorAccount.new(
      client_id: client_id.to_s,
      client_secret: resolve_secret_credential(client_id.to_s),
      redirect_uris: config[:redirect_uris],
      post_logout_redirect_uris: config[:post_logout_redirect_uris] || [],
      backchannel_logout_uris: config[:backchannel_logout_uris] || [],
      backchannel_logout_session_required: config.fetch(:backchannel_logout_session_required, false),
      aud: config[:aud],
      resource_type: config[:resource_type],
      name: config[:name],
      domains: domains_from_redirect_uris(config[:redirect_uris]),
      registered_token_endpoint_auth_method: registered_auth_method,
      metadata_token_endpoint_auth_method: registered_auth_method || metadata_auth_method(client_id.to_s),
      jwt_namespace: config[:jwt_namespace],
    )
  end

  # @param client_id [String]
  # @return [VisitorAccount]
  # @raise [ClientNotFound]
  def find!(client_id)
    find(client_id) || raise(ClientNotFound, "Unknown OIDC client: #{client_id}")
  end

  # @param client_id [String]
  # @param uri [String]
  # @return [Boolean]
  def valid_redirect_uri?(client_id, uri)
    client = find(client_id)
    return false unless client

    client.redirect_uris.include?(uri)
  end

  def valid_post_logout_redirect_uri?(client_id:, uri:)
    client = find(client_id)
    return false unless client

    client.post_logout_redirect_uris.include?(uri)
  end

  def backchannel_logout_uris_for(client_id:, resource_type: nil)
    filter_logout_uris(find(client_id)&.backchannel_logout_uris || [], resource_type)
  end

  def logout_clients_for_resource_type(resource_type)
    clients.filter_map do |client_id, config|
      next if filter_logout_uris(Array(config[:backchannel_logout_uris]), resource_type).blank?

      find(client_id)
    end
  end

  # @param client_id [String]
  # @param secret_credential [String]
  # @return [Boolean]
  def authenticate(client_id, secret_credential)
    client = find(client_id)
    return false unless client
    return false if client.client_secret.blank? || secret_credential.blank?

    ActiveSupport::SecurityUtils.secure_compare(client.client_secret, secret_credential)
  end

  def authenticate_assertion(client_id, assertion, token_url:)
    client = find(client_id)
    return false unless client&.private_key_jwt_client?

    OidcClientAssertionJwt.valid?(client_id: client_id, assertion: assertion, token_url: token_url)
  end

  def jwt_namespace_for(client_id)
    find(client_id)&.jwt_namespace
  end

  def client_ids
    clients.keys
  end

  def audiences_for_resource_type(resource_type)
    normalized_resource_type = normalize_resource_type(resource_type)

    clients.values.filter_map do |config|
      next unless normalize_resource_type(config[:resource_type]) == normalized_resource_type

      config[:aud]
    end.uniq
  end

  # --- private ---

  def clients
    cached_clients = CLIENTS_CACHE.get
    return cached_clients if cached_clients

    CLIENTS_MUTEX.synchronize do
      CLIENTS_CACHE.get || begin
        built_clients = build_clients
        CLIENTS_CACHE.set(built_clients)
        built_clients
      end
    end
  end

  def build_clients
    {
      # Sign credential gateway as RP. This is an RP client-auth key only; Sign remains non-OP.
      "sign-rp" => {
        redirect_uris: build_redirect_uris("SIGN_SERVICE_URL", "id.app.localhost") +
          build_redirect_uris("SIGN_STAFF_URL", "id.org.localhost") +
          build_redirect_uris("SIGN_CORPORATE_URL", "id.com.localhost"),
        post_logout_redirect_uris: build_post_logout_redirect_uris("SIGN_SERVICE_URL", "id.app.localhost") +
          build_post_logout_redirect_uris("SIGN_STAFF_URL", "id.org.localhost") +
          build_post_logout_redirect_uris("SIGN_CORPORATE_URL", "id.com.localhost"),
        backchannel_logout_uris: build_logout_uris("SIGN_SERVICE_URL", "id.app.localhost", "backchannel_logout") +
          build_logout_uris("SIGN_STAFF_URL", "id.org.localhost", "backchannel_logout") +
          build_logout_uris("SIGN_CORPORATE_URL", "id.com.localhost", "backchannel_logout"),
        backchannel_logout_session_required: true,
        aud: "sign-rp",
        resource_type: "client",
        name: "Sign RP",
        token_endpoint_auth_method: "private_key_jwt",
        jwt_namespace: "SIGN_APP",
      },
      # Acme/Base Rails browser RP.
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
        token_endpoint_auth_method: "private_key_jwt",
        jwt_namespace: "ACME_APP",
      },
      # Core browser RP.
      "core-next-rp" => {
        redirect_uris: build_redirect_uris("CORE_SERVICE_URL", "www.jp.umaxica.app") +
          build_redirect_uris("CORE_STAFF_URL", "www.jp.umaxica.org") +
          build_redirect_uris("CORE_CORPORATE_URL", "www.jp.umaxica.com"),
        post_logout_redirect_uris: build_post_logout_redirect_uris("CORE_SERVICE_URL", "www.jp.umaxica.app") +
          build_post_logout_redirect_uris("CORE_STAFF_URL", "www.jp.umaxica.org") +
          build_post_logout_redirect_uris("CORE_CORPORATE_URL", "www.jp.umaxica.com"),
        backchannel_logout_uris: build_logout_uris("CORE_SERVICE_URL", "www.jp.umaxica.app", "backchannel/logout") +
          build_logout_uris("CORE_STAFF_URL", "www.jp.umaxica.org", "backchannel/logout") +
          build_logout_uris("CORE_CORPORATE_URL", "www.jp.umaxica.com", "backchannel/logout"),
        backchannel_logout_session_required: true,
        aud: "core-next-rp",
        resource_type: "client",
        name: "Core Next RP",
        token_endpoint_auth_method: "private_key_jwt",
        jwt_namespace: "CORE_APP",
      },
      "app-ios-rp" => {
        redirect_uris: ["umaxica://oauth/callback"],
        aud: "palm-api",
        resource_type: "client",
        name: "App iOS RP",
        token_endpoint_auth_method: "none",
      },
      "app-android-rp" => {
        redirect_uris: ["com.umaxica.app:/oauth/callback"],
        aud: "palm-api",
        resource_type: "client",
        name: "App Android RP",
        token_endpoint_auth_method: "none",
      },
      # Docs
      "docs_app" => {
        redirect_uris: build_redirect_uris("DOCS_SERVICE_URL", "docs.app.localhost"),
        aud: "umaxica-docs-app",
        resource_type: "client",
        name: "Docs App",
      },
      "docs_org" => {
        redirect_uris: build_redirect_uris("DOCS_STAFF_URL", "docs.org.localhost"),
        aud: "umaxica-docs-org",
        resource_type: "operator",
        name: "Docs Org",
      },
      "docs_com" => {
        redirect_uris: build_redirect_uris("DOCS_CORPORATE_URL", "docs.com.localhost"),
        aud: "umaxica-docs-com",
        resource_type: "visitor",
        name: "Docs Com",
      },
      # News
      "news_app" => {
        redirect_uris: build_redirect_uris("NEWS_SERVICE_URL", "news.app.localhost"),
        aud: "umaxica-news-app",
        resource_type: "client",
        name: "News App",
      },
      "news_org" => {
        redirect_uris: build_redirect_uris("NEWS_STAFF_URL", "news.org.localhost"),
        aud: "umaxica-news-org",
        resource_type: "operator",
        name: "News Org",
      },
      "news_com" => {
        redirect_uris: build_redirect_uris("NEWS_CORPORATE_URL", "news.com.localhost"),
        aud: "umaxica-news-com",
        resource_type: "visitor",
        name: "News Com",
      },
      # Help
      "help_app" => {
        redirect_uris: build_redirect_uris("HELP_SERVICE_URL", "help.app.localhost"),
        aud: "umaxica-help-app",
        resource_type: "client",
        name: "Help App",
      },
      "help_org" => {
        redirect_uris: build_redirect_uris("HELP_STAFF_URL", "help.org.localhost"),
        aud: "umaxica-help-org",
        resource_type: "operator",
        name: "Help Org",
      },
      "help_com" => {
        redirect_uris: build_redirect_uris("HELP_CORPORATE_URL", "help.com.localhost"),
        aud: "umaxica-help-com",
        resource_type: "visitor",
        name: "Help Com",
      },
    }.freeze
  end

  def build_redirect_uris(env_key, default_host)
    host = ENV.fetch(env_key, default_host)
    protocol = (Rails.env.production? || public_host?(host)) ? "https" : "http"
    port_suffix = (Rails.env.production? || public_host?(host)) ? "" : ":#{ENV.fetch("PORT", "3000")}"
    ["#{protocol}://#{host}#{port_suffix}/auth/callback"]
  end

  def build_post_logout_redirect_uris(env_key, default_host)
    host = ENV.fetch(env_key, default_host)
    protocol = (Rails.env.production? || public_host?(host)) ? "https" : "http"
    port_suffix = (Rails.env.production? || public_host?(host)) ? "" : ":#{ENV.fetch("PORT", "3000")}"
    ["#{protocol}://#{host}#{port_suffix}/signed-out"]
  end

  def build_logout_uris(env_key, default_host, endpoint)
    host = ENV.fetch(env_key, default_host)
    protocol = (Rails.env.production? || public_host?(host)) ? "https" : "http"
    port_suffix = (Rails.env.production? || public_host?(host)) ? "" : ":#{ENV.fetch("PORT", "3000")}"
    ["#{protocol}://#{host}#{port_suffix}/oidc/#{endpoint}"]
  end

  def public_host?(host)
    normalized_host = URI.parse("//#{host}").host.to_s

    normalized_host.present? &&
      LOOPBACK_HOST_TOKENS.none? { |token| normalized_host.include?(token) }
  rescue URI::InvalidURIError
    false
  end

  def resolve_secret_credential(client_id)
    Rails.app.creds.option(credential_key_for(client_id))
  end

  # This method is metadata/diagnostic-only. It must not be used for token endpoint authentication
  # or authorization decisions.
  def metadata_auth_method(client_id)
    "client_secret_post"
  end

  def domains_from_redirect_uris(redirect_uris)
    redirect_uris.filter_map { |uri| URI.parse(uri).host.presence }.uniq
  rescue URI::InvalidURIError
    []
  end

  def filter_logout_uris(uris, resource_type)
    return uris if resource_type.blank?

    normalized_resource_type = normalize_resource_type(resource_type)
    uris.select do |uri|
      logout_uri_resource_type(uri) == normalized_resource_type
    end
  end

  def logout_uri_resource_type(uri)
    host = URI.parse(uri.to_s).host.to_s
    return "operator" if logout_hosts_for("operator").include?(host)
    return "visitor" if logout_hosts_for("visitor").include?(host)

    "client"
  rescue URI::InvalidURIError
    nil
  end

  def logout_hosts_for(resource_type)
    case normalize_resource_type(resource_type)
    when "operator"
      [
        ENV.fetch("SIGN_STAFF_URL", "id.org.localhost"),
        ENV.fetch("CORE_STAFF_URL", "www.jp.umaxica.org"),
      ]
    when "visitor"
      [
        ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost"),
        ENV.fetch("CORE_CORPORATE_URL", "www.jp.umaxica.com"),
      ]
    else
      [
        ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
        ENV.fetch("CORE_SERVICE_URL", "www.jp.umaxica.app"),
      ]
    end
  end

  def credential_key_for(client_id)
    :"OIDC_CLIENT_SECRETS_#{client_id.to_s.upcase}"
  end

  def normalize_resource_type(resource_type)
    case resource_type.to_s
    when "operator", "staff" then "operator"
    when "visitor", "customer" then "visitor"
    else "client"
    end
  end

  private_class_method :clients, :build_clients, :build_redirect_uris, :build_post_logout_redirect_uris,
                       :build_logout_uris, :public_host?,
                       :resolve_secret_credential, :domains_from_redirect_uris, :credential_key_for,
                       :filter_logout_uris, :logout_uri_resource_type, :logout_hosts_for,
                       :normalize_resource_type, :metadata_auth_method
end
