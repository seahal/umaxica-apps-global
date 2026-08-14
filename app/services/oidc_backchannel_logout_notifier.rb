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

    jobs =
      clients.flat_map do |client|
        OidcClientRegistry.backchannel_logout_uris_for(
          client_id: client.client_id,
          resource_type: resource_type,
        ).map do |uri|
          OidcBackchannelLogoutDeliveryJob.new(
            OutboundSensitivePayload.encrypt_oidc_backchannel_logout(
              uri:, client_id: client.client_id, resource_type:, subject:, sid:,
            ),
          )
        end
      end

    enqueue_jobs(jobs)
    jobs.size
  end

  private

  attr_reader :resource_type, :subject, :sid, :initiating_client_id

  def clients
    OidcClientRegistry.logout_clients_for_resource_type(resource_type)
  end

  def enqueue_jobs(jobs)
    return if jobs.empty?

    adapter = ActiveJob::Base.queue_adapter
    return adapter.enqueue_all(jobs) if adapter.respond_to?(:enqueue_all)

    jobs.each(&:enqueue)
  end
end
