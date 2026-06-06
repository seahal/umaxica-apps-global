# typed: false
# frozen_string_literal: true

require "concurrent"

module OidcClientRegistry
  class ClientNotFound < StandardError; end

  class InvalidRedirectUri < StandardError; end

  VisitorAccount =
    Data.define(
      :client_id, :client_secret, :redirect_uris, :aud, :resource_type,
      :name, :domains, :token_endpoint_auth_method, :jwt_namespace,
    )
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

    VisitorAccount.new(
      client_id: client_id.to_s,
      client_secret: resolve_secret_credential(client_id.to_s),
      redirect_uris: config[:redirect_uris],
      aud: config[:aud],
      resource_type: config[:resource_type],
      name: config[:name],
      domains: domains_from_redirect_uris(config[:redirect_uris]),
      token_endpoint_auth_method: config[:token_endpoint_auth_method] || default_auth_method(client_id.to_s),
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
    return false unless client&.token_endpoint_auth_method == "private_key_jwt"

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
      # Acme
      "acme_app" => {
        redirect_uris: build_redirect_uris("ACME_SERVICE_URL", "www.app.localhost"),
        aud: "umaxica-acme-app",
        resource_type: "client",
        name: "Acme App",
        token_endpoint_auth_method: "private_key_jwt",
        jwt_namespace: "ACME_APP",
      },
      "acme_org" => {
        redirect_uris: build_redirect_uris("ACME_STAFF_URL", "www.org.localhost"),
        aud: "umaxica-acme-org",
        resource_type: "operator",
        name: "Acme Org",
        token_endpoint_auth_method: "private_key_jwt",
        jwt_namespace: "ACME_ORG",
      },
      "acme_com" => {
        redirect_uris: build_redirect_uris("ACME_CORPORATE_URL", "www.com.localhost"),
        aud: "umaxica-acme-com",
        resource_type: "visitor",
        name: "Acme Com",
        token_endpoint_auth_method: "private_key_jwt",
        jwt_namespace: "ACME_COM",
      },
      # Core
      "core_app" => {
        redirect_uris: build_redirect_uris("CORE_SERVICE_URL", "www.jp.umaxica.app"),
        aud: "umaxica-core-app",
        resource_type: "client",
        name: "Core App",
        token_endpoint_auth_method: "private_key_jwt",
        jwt_namespace: "CORE_APP",
      },
      "core_org" => {
        redirect_uris: build_redirect_uris("CORE_STAFF_URL", "www.jp.umaxica.org"),
        aud: "umaxica-core-org",
        resource_type: "operator",
        name: "Core Org",
        token_endpoint_auth_method: "private_key_jwt",
        jwt_namespace: "CORE_ORG",
      },
      "core_com" => {
        redirect_uris: build_redirect_uris("CORE_CORPORATE_URL", "www.jp.umaxica.com"),
        aud: "umaxica-core-com",
        resource_type: "visitor",
        name: "Core Com",
        token_endpoint_auth_method: "private_key_jwt",
        jwt_namespace: "CORE_COM",
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

  def default_auth_method(client_id)
    resolve_secret_credential(client_id).present? ? "client_secret_post" : "none"
  end

  def domains_from_redirect_uris(redirect_uris)
    redirect_uris.filter_map { |uri| URI.parse(uri).host.presence }.uniq
  rescue URI::InvalidURIError
    []
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

  private_class_method :clients, :build_clients, :build_redirect_uris, :public_host?,
                       :resolve_secret_credential, :domains_from_redirect_uris, :credential_key_for,
                       :normalize_resource_type, :default_auth_method
end
