# typed: false
# frozen_string_literal: true

class OidcFrontchannelLogoutUrls < ApplicationService
  def initialize(resource_type:, sid:)
    super()
    @resource_type = resource_type
    @sid = sid
  end

  def call
    return [] if sid.blank?

    OidcClientRegistry.logout_clients_for_resource_type(resource_type).flat_map do |client|
      OidcClientRegistry.frontchannel_logout_uris_for(
        client_id: client.client_id,
        resource_type: resource_type,
      ).filter_map do |uri|
        append_query(uri)
      end
    end.uniq
  end

  private

  attr_reader :resource_type, :sid

  def append_query(uri)
    parsed = URI.parse(uri)
    query = Rack::Utils.parse_nested_query(parsed.query.to_s)
    query["iss"] = OidcIssuer.for_resource_type(resource_type)
    query["sid"] = sid
    parsed.query = query.to_query
    parsed.to_s
  rescue URI::InvalidURIError
    nil
  end
end
