# typed: false
# frozen_string_literal: true

module OidcRedirectUriValidator
  module_function

  def valid_redirect_uri?(client, uri, resource_type: nil)
    return Array(client&.redirect_uris).include?(uri) if resource_type.nil?

    Array(client&.redirect_uris_by_realm&.fetch(resource_type.to_s, nil)).include?(uri)
  end

  def valid_post_logout_redirect_uri?(client, uri)
    Array(client&.post_logout_redirect_uris).include?(uri)
  end
end
