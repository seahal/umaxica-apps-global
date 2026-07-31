# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  class CallbackResult < Data.define(:status, :principal, :credential_candidate, :failure)
    STATUSES = %i(verified failed).freeze

    def self.verified(principal:, credential_candidate: nil)
      new(
        status: :verified,
        principal: principal,
        credential_candidate: credential_candidate,
        failure: nil,
      )
    end

    def self.failed(failure:)
      new(
        status: :failed,
        principal: nil,
        credential_candidate: nil,
        failure: failure,
      )
    end

    def initialize(status:, principal:, credential_candidate:, failure:)
      raise ArgumentError, "status is unsupported" unless STATUSES.include?(status)

      case status
      when :verified
        unless principal.is_a?(VerifiedPrincipal)
          raise ArgumentError, "verified result requires a principal and no failure"
        end
        unless failure.nil?
          raise ArgumentError, "verified result requires a principal and no failure"
        end
      when :failed
        unless principal.nil? && credential_candidate.nil? && failure.is_a?(Failure)
          raise ArgumentError, "failed result requires only a typed failure"
        end
      end

      super
    end

    def verified? = status == :verified

    def failed? = status == :failed
  end
end
