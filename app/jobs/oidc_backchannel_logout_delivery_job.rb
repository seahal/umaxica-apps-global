# typed: false
# frozen_string_literal: true

class OidcBackchannelLogoutDeliveryJob < ApplicationJob
  queue_as :default

  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 3

  def perform(encrypted_payload, *legacy_payload)
    payload = delivery_payload(encrypted_payload, legacy_payload)
    client_id = payload.fetch(:client_id)
    return log_suspended(client_id) if suspended?(client_id)

    parsed_uri = registered_uri!(payload)
    logout_token = OidcLogoutTokenCodec.encode(
      client_id: client_id,
      resource_type: payload.fetch(:resource_type),
      subject: payload.fetch(:subject),
      sid: payload.fetch(:sid),
    )
    response = post_logout_token(parsed_uri, logout_token)
    Rails.logger.info(
      JitLogEvent.format(
        "oidc.backchannel_logout.delivered",
        client_id: client_id,
        host: parsed_uri.host,
        status: response.status,
      ),
    )
  rescue URI::InvalidURIError, IOError, *OutboundHttp::Connection::NETWORK_ERRORS => e
    Rails.logger.info(
      JitLogEvent.format(
        "oidc.backchannel_logout.delivery_failed",
        client_id: defined?(client_id) ? client_id : nil,
        error_class: e.class.name,
      ),
    )
  end

  private

  # Five-argument jobs may remain in a deployed queue during rollout. New
  # producers only enqueue the versioned encrypted envelope.
  def delivery_payload(encrypted_payload, legacy_payload)
    return OutboundSensitivePayload.decrypt_oidc_backchannel_logout(encrypted_payload) if legacy_payload.empty?

    raise ArgumentError, "Invalid legacy OIDC back-channel logout payload" unless legacy_payload.size == 4

    uri, client_id, resource_type, subject, sid = [encrypted_payload, *legacy_payload]
    { uri:, client_id:, resource_type:, subject:, sid: }
  end

  def registered_uri!(payload)
    client_id = payload.fetch(:client_id)
    resource_type = payload.fetch(:resource_type)
    uri = payload.fetch(:uri)
    registered = OidcClientRegistry.backchannel_logout_uris_for(client_id:, resource_type:)
    raise ArgumentError, "OIDC back-channel logout destination is no longer registered" unless registered.include?(uri)

    URI.parse(uri)
  end

  def suspended?(client_id)
    FeatureFlags.enabled?(
      :oidc_backchannel_logout_suspended,
      OidcClientFlipperActor.new(client_id: client_id.to_s),
    )
  end

  def log_suspended(client_id)
    Rails.logger.warn(
      JitLogEvent.format("oidc.backchannel_logout.suspended", client_id: client_id),
    )
    nil
  end

  # No connection-level retry and no redirect following. ActiveJob already
  # retries this delivery, and the destination is an allowlisted relying-party
  # URI: following a redirect off that list would reintroduce the SSRF the
  # registry check in registered_uri! exists to prevent.
  #
  # require_https is false because the scheme comes from the client registration
  # rather than from this job, matching the previous `use_ssl: scheme == "https"`.
  def post_logout_token(uri, logout_token)
    connection = OutboundHttp::Connection.build(
      url: uri,
      open_timeout: OPEN_TIMEOUT,
      read_timeout: READ_TIMEOUT,
      require_https: false,
    )
    connection.post(uri, "logout_token" => logout_token)
  end
end
