# typed: false
# frozen_string_literal: true

module OidcIssuer
  LOOPBACK_HOST_TOKENS = %w(localhost 127.0.0.1 ::1).freeze

  module_function

  def for_client(client)
    for_resource_type(resource_type_for_client(client))
  end

  def for_resource_type(resource_type)
    absolute_url(host_for_resource_type(resource_type))
  end

  def jwks_uri(resource_type)
    "#{for_resource_type(resource_type)}/.well-known/jwks.json"
  end

  def authorization_endpoint(resource_type)
    "#{for_resource_type(resource_type)}/oauth/authorize"
  end

  def token_endpoint(resource_type)
    "#{for_resource_type(resource_type)}/oauth/token"
  end

  def userinfo_endpoint(resource_type)
    "#{for_resource_type(resource_type)}/oauth/userinfo"
  end

  def revocation_endpoint(resource_type)
    "#{for_resource_type(resource_type)}/oauth/revoke"
  end

  def end_session_endpoint(resource_type)
    "#{for_resource_type(resource_type)}/oidc/logout"
  end

  def host_for_client(client)
    host_for_resource_type(resource_type_for_client(client))
  end

  def host_for_resource_type(resource_type)
    case resource_type.to_s
    when "operator", "staff"
      ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    when "visitor", "customer"
      ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    else
      ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    end
  end

  def jwt_issuer_id_for_client(client)
    jwt_issuer_id_for_resource_type(resource_type_for_client(client))
  end

  def jwt_issuer_id_for_resource_type(resource_type)
    namespace =
      case resource_type.to_s
      when "operator", "staff" then "ACME_ORG"
      when "visitor", "customer" then "ACME_COM"
      else "ACME_APP"
      end

    "surface:#{namespace}"
  end

  def resource_type_for_client(client)
    case client.resource_type.to_s
    when "operator", "staff" then "operator"
    when "visitor", "customer" then "visitor"
    else "client"
    end
  end

  def absolute_url(host_or_url)
    normalized = host_or_url.to_s.strip
    return normalized.delete_suffix("/") if normalized.match?(%r{\Ahttps?://})

    "#{scheme_for(normalized)}://#{normalized}#{port_suffix_for(normalized)}"
  end

  def scheme_for(host)
    (Rails.env.production? || public_host?(host)) ? "https" : "http"
  end

  def port_suffix_for(host)
    return "" if Rails.env.production? || public_host?(host)
    return "" if host.include?(":")

    ":#{ENV.fetch("PORT", "3000")}"
  end

  def public_host?(host)
    normalized_host = URI.parse("//#{host}").host.to_s
    normalized_host.present? &&
      LOOPBACK_HOST_TOKENS.none? { |token| normalized_host.include?(token) }
  rescue URI::InvalidURIError
    false
  end
end
