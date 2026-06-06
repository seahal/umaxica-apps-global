# typed: false
# frozen_string_literal: true

require "net/http"

class OidcRpTokenClient < ApplicationService
  Result =
    Data.define(:success, :token_response, :error) do
      def success? = success
    end

  def initialize(token_url:, client_id:, client_secret:, code:, redirect_uri:, code_verifier:)
    super()
    @token_url = token_url
    @client_id = client_id
    @client_secret = client_secret
    @code = code
    @redirect_uri = redirect_uri
    @code_verifier = code_verifier
  end

  def call
    uri = URI.parse(token_url)
    response = Net::HTTP.post_form(uri, request_params)
    body = JSON.parse(response.body.presence || "{}").with_indifferent_access
    return Result.new(success: true, token_response: body, error: nil) if response.is_a?(Net::HTTPSuccess)

    Result.new(success: false, token_response: nil, error: body[:error].presence || "token_exchange_failed")
  rescue JSON::ParserError, URI::InvalidURIError, SocketError, SystemCallError, Timeout::Error
    Result.new(success: false, token_response: nil, error: "token_exchange_failed")
  end

  private

  attr_reader :token_url, :client_id, :client_secret, :code, :redirect_uri, :code_verifier

  def request_params
    params = {
      grant_type: "authorization_code",
      code: code,
      redirect_uri: redirect_uri,
      client_id: client_id,
      code_verifier: code_verifier,
    }
    assertion = OidcClientAssertionJwt.issue(client_id: client_id, token_url: token_url)
    if assertion.present?
      params.merge(
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: assertion,
      )
    else
      params.merge(client_secret: client_secret)
    end
  end
end
