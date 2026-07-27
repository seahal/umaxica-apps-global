# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  class AppleCredentialRevocationAdapter
    include AppleCredentialRevocationPort

    REVOCATION_URL = "https://appleid.apple.com/auth/revoke"
    RETRYABLE_STATUS_CODES = [429, *500..599].freeze

    def self.from_credentials
      client_id = Rails.app.creds.option(:OMNI_AUTH_APPLE_CLIENT_ID)
      new(client_id: client_id, client_secret_provider: AppleClientSecretProvider.from_credentials)
    end

    def initialize(client_id:, client_secret_provider:, http_client: Faraday)
      @client_id = required_string(client_id, "client_id")
      @client_secret_provider = client_secret_provider
      @http_client = http_client
      validate_client_secret_provider!
    end

    def call(refresh_token:)
      token = required_string(refresh_token, "refresh_token")
      response = http_client.post(REVOCATION_URL, request_body(token))

      classify(response.status)
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed
      CredentialRevocationResult.new(status: :failed, code: :network_failure)
    end

    private

    attr_reader :client_id, :client_secret_provider, :http_client

    def request_body(refresh_token)
      {
        client_id: client_id,
        client_secret: client_secret_provider.call,
        token: refresh_token,
        token_type_hint: "refresh_token",
      }
    end

    def classify(status)
      return CredentialRevocationResult.new(status: :revoked_or_already_invalid) if status == 200
      return CredentialRevocationResult.new(status: :failed, code: :rate_limited) if status == 429
      return CredentialRevocationResult.new(status: :failed, code: :provider_unavailable) if (500..599).cover?(status)

      CredentialRevocationResult.new(status: :failed, code: :provider_rejected)
    end

    def validate_client_secret_provider!
      return if client_secret_provider.respond_to?(:call)

      raise ArgumentError, "client_secret_provider must respond to call"
    end

    def required_string(value, name)
      return value if value.is_a?(String) && value.present?

      raise ArgumentError, "#{name} is required"
    end
  end
end
