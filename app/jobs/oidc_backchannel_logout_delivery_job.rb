# typed: false
# frozen_string_literal: true

class OidcBackchannelLogoutDeliveryJob < ApplicationJob
  queue_as :default

  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 3

  def perform(uri, client_id, resource_type, subject, sid)
    parsed_uri = URI.parse(uri.to_s)
    logout_token = OidcLogoutTokenCodec.encode(
      client_id: client_id,
      resource_type: resource_type,
      subject: subject,
      sid: sid,
    )
    response = post_logout_token(parsed_uri, logout_token)
    Rails.logger.info(
      JitLogEvent.format(
        "oidc.backchannel_logout.delivered",
        client_id: client_id,
        host: parsed_uri.host,
        status: response.code.to_i,
      ),
    )
  rescue URI::InvalidURIError, SocketError, SystemCallError, IOError, Timeout::Error, OpenSSL::SSL::SSLError => e
    Rails.logger.info(
      JitLogEvent.format(
        "oidc.backchannel_logout.delivery_failed",
        client_id: client_id,
        error_class: e.class.name,
      ),
    )
  end

  private

  def post_logout_token(uri, logout_token)
    Net::HTTP.start(
      uri.host,
      uri.port,
      use_ssl: uri.scheme == "https",
      open_timeout: OPEN_TIMEOUT,
      read_timeout: READ_TIMEOUT,
    ) do |http|
      request = Net::HTTP::Post.new(uri.request_uri)
      request.set_form_data("logout_token" => logout_token)
      http.request(request)
    end
  end
end
