# typed: false
# frozen_string_literal: true

class OidcBackchannelLogoutNotifier < ApplicationService
  def initialize(resource_type:, subject:, sid:, initiating_client_id: nil)
    super()
    @resource_type = resource_type
    @subject = subject
    @sid = sid
    @initiating_client_id = initiating_client_id
  end

  def call
    return 0 if sid.blank? && subject.blank?
    raise ArgumentError, "logout token requires sid" if sid.blank?

    clients.sum do |client|
      OidcClientRegistry.backchannel_logout_uris_for(
        client_id: client.client_id,
        resource_type: resource_type,
      ).each do |uri|
        OidcBackchannelLogoutDeliveryJob.perform_later(
          uri,
          client.client_id,
          resource_type,
          subject,
          sid,
        )
      end.size
    end
  end

  private

  attr_reader :resource_type, :subject, :sid, :initiating_client_id

  def clients
    OidcClientRegistry.logout_clients_for_resource_type(resource_type)
  end
end
