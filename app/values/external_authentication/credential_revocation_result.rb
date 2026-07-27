# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  class CredentialRevocationResult
    SUCCESS_STATUSES = %i(revoked_or_already_invalid).freeze
    RETRYABLE_CODES = %i(provider_unavailable rate_limited network_failure).freeze

    attr_reader :status, :code

    def initialize(status:, code: nil)
      @status = status.to_sym
      @code = code&.to_sym
      validate!
      freeze
    end

    def successful?
      SUCCESS_STATUSES.include?(status)
    end

    def retryable?
      RETRYABLE_CODES.include?(code)
    end

    private

    def validate!
      return if successful? && code.nil?
      return if status == :failed && code.present?

      raise ArgumentError, "status and code are invalid"
    end
  end
end
