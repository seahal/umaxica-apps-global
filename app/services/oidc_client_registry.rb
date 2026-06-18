# typed: false
# frozen_string_literal: true

require "concurrent"

module OidcClientRegistry
  class ClientNotFound < StandardError; end

  class InvalidRedirectUri < StandardError; end

  DEFAULT_ALLOWED_SCOPES = %w(openid profile email).freeze
  PALM_ALLOWED_SCOPES = (DEFAULT_ALLOWED_SCOPES + %w(palm.read)).freeze

  VisitorAccount =
    Data.define(
      :client_id, :client_secret, :redirect_uris, :post_logout_redirect_uris, :aud, :resource_type,
      :name, :domains, :allowed_scopes, :registered_token_endpoint_auth_method,
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
      allowed_scopes: normalize_allowed_scopes(config.fetch(:allowed_scopes, DEFAULT_ALLOWED_SCOPES)),
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

    OidcRedirectUriValidator.valid_redirect_uri?(client, uri)
  end

  def valid_post_logout_redirect_uri?(client_id:, uri:)
    client = find(client_id)

    OidcRedirectUriValidator.valid_post_logout_redirect_uri?(client, uri)
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

  def normalize_allowed_scopes(allowed_scopes)
    Array(allowed_scopes).map(&:to_s).freeze
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
    OidcClientStoresStaticClientStore.clients
  end

  def resolve_secret_credential(client_id)
    OidcClientSecretResolver.resolve(client_id)
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

  def public_host?(host)
    parsed_host = normalize_host(host)
    return false if parsed_host.blank?

    uri = URI.parse("//#{parsed_host}")
    return false if uri.host.blank?

    ip = IPAddr.new(uri.host)
    !ip.loopback? && !ip.private? && !ip.link_local?
  rescue IPAddr::InvalidAddressError
    uri.host.present? && uri.host != "localhost"
  rescue URI::InvalidURIError
    false
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
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    case normalize_resource_type(resource_type)
    when "operator"
      [
        normalize_host(hosts.sign_staff),
        normalize_host(hosts.core_staff),
      ]
    when "visitor"
      [
        normalize_host(hosts.sign_corporate),
        normalize_host(hosts.core_corporate),
      ]
    else
      [
        normalize_host(hosts.sign_service),
        normalize_host(hosts.core_service),
      ]
    end
  end

  def normalize_resource_type(resource_type)
    case resource_type.to_s
    when "operator", "staff" then "operator"
    when "visitor", "customer" then "visitor"
    else "client"
    end
  end

  def normalize_host(host)
    parsed_host = URI.parse(host.to_s).host if host.to_s.include?("://")
    parsed_host.presence || URI.parse("//#{host}").host.to_s.presence || host.to_s
  rescue URI::InvalidURIError
    host.to_s
  end

  private_class_method :clients, :build_clients,
                       :resolve_secret_credential, :domains_from_redirect_uris,
                       :public_host?,
                       :filter_logout_uris, :logout_uri_resource_type, :logout_hosts_for,
                       :normalize_resource_type, :metadata_auth_method, :normalize_allowed_scopes,
                       :normalize_host
end
