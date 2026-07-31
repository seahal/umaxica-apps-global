# typed: false
# frozen_string_literal: true

require "net/http"

class OidcRpTokenClient < ApplicationService
  Result =
    Data.define(:success, :token_response, :error) do
      def success? = success
    end

  def initialize(token_url:, client_id:, client_secret:, code:, redirect_uri:, code_verifier:, client_assertion: nil)
    super()
    @token_url = token_url
    @client_id = client_id
    @client_secret = client_secret
    @client_assertion = client_assertion
    @code = code
    @redirect_uri = redirect_uri
    @code_verifier = code_verifier
  end

  def call
    uri = URI.parse(token_url)
    params = request_params
    return params if params.is_a?(Result)

    response = Net::HTTP.post_form(uri, params)
    body = JSON.parse(response.body.presence || "{}").with_indifferent_access
    return Result.new(success: true, token_response: body, error: nil) if response.is_a?(Net::HTTPSuccess)

    log_token_exchange_failure(uri: uri, response: response, oauth_error: body[:error].presence)
    Result.new(success: false, token_response: nil, error: body[:error].presence || "token_exchange_failed")
  rescue JSON::ParserError, URI::InvalidURIError, SocketError, SystemCallError, Timeout::Error => e
    log_token_exchange_failure(uri: safe_token_uri, error_class: e.class.name)
    Result.new(success: false, token_response: nil, error: "token_exchange_failed")
  end

  private

  attr_reader :token_url, :client_id, :client_secret, :client_assertion, :code, :redirect_uri, :code_verifier

  def request_params
    params = {
      grant_type: "authorization_code",
      code: code,
      redirect_uri: redirect_uri,
      client_id: client_id,
      code_verifier: code_verifier,
    }
    if client_assertion.present?
      return params.merge(
        client_assertion_type: ExternalAuthentication::EntraClientAssertionAdapter::ASSERTION_TYPE,
        client_assertion: client_assertion,
      )
    end
    client = OidcClientRegistry.find(client_id)
    if client&.private_key_jwt_client?
      assertion = OidcClientAssertionJwt.issue(client_id: client_id, token_url: token_url)
      return Result.new(success: false, token_response: nil, error: "client_assertion_unavailable") if assertion.blank?

      return params.merge(
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: assertion,
      )
    end

    params.merge(client_secret: client_secret)
  end

  def log_token_exchange_failure(uri:, response: nil, oauth_error: nil, error_class: nil)
    Rails.logger.info(
      JitLogEvent.format(
        "oidc.rp.token_exchange.failed",
        client_id: client_id,
        endpoint_host: uri&.host,
        endpoint_path: uri&.path,
        http_status: response&.code&.to_i,
        oauth_error: oauth_error,
        error_class: error_class,
      ),
    )
  end

  def safe_token_uri
    URI.parse(token_url)
  rescue URI::InvalidURIError
    nil
  end
end
