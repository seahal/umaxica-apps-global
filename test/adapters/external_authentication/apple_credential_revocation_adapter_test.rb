# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationAppleCredentialRevocationAdapterTest < ActiveSupport::TestCase
  Response = Data.define(:status)

  class FakeHttpClient
    attr_reader :requests

    def initialize(response:)
      @response = response
      @requests = []
    end

    def post(url, body)
      requests << { url: url, body: body }
      @response
    end
  end

  test "posts a refresh-token revocation request and accepts Apple's idempotent success status" do
    http_client = FakeHttpClient.new(response: Response.new(200))
    adapter = build_adapter(http_client:)

    result = adapter.call(refresh_token: "refresh-token")

    assert_predicate result, :successful?
    assert_equal :revoked_or_already_invalid, result.status
    assert_equal "https://appleid.apple.com/auth/revoke", http_client.requests.first.fetch(:url)
    assert_equal(
      {
        client_id: "com.example.web",
        client_secret: "client-secret-jwt",
        token: "refresh-token",
        token_type_hint: "refresh_token",
      },
      http_client.requests.first.fetch(:body),
    )
  end

  test "classifies transient provider failures without retaining the response body" do
    adapter = build_adapter(http_client: FakeHttpClient.new(response: Response.new(503)))

    result = adapter.call(refresh_token: "refresh-token")

    assert_predicate result, :retryable?
    assert_equal :provider_unavailable, result.code
  end

  test "rejects a missing refresh token before making an HTTP request" do
    http_client = FakeHttpClient.new(response: Response.new(200))
    adapter = build_adapter(http_client:)

    error = assert_raises(ArgumentError) { adapter.call(refresh_token: "") }

    assert_equal "refresh_token is required", error.message
    assert_empty http_client.requests
  end

  private

  def build_adapter(http_client:)
    client_secret_provider = Object.new
    client_secret_provider.define_singleton_method(:call) { "client-secret-jwt" }

    ExternalAuthentication::AppleCredentialRevocationAdapter.new(
      client_id: "com.example.web",
      client_secret_provider: client_secret_provider,
      http_client: http_client,
    )
  end
end
