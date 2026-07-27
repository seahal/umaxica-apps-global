# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  class VerifiedPrincipal < Data.define(
    :provider,
    :subject,
    :issuer,
    :audience,
    :verified_at,
    :verification_authority,
  )
    PROVIDERS = %w(apple google).freeze

    def initialize(provider:, subject:, issuer:, audience:, verified_at:, verification_authority:)
      raise ArgumentError, "provider is unsupported" unless PROVIDERS.include?(provider)
      raise ArgumentError, "subject is required" unless subject.is_a?(String) && subject.present?
      raise ArgumentError, "issuer is required" unless issuer.is_a?(String) && issuer.present?
      raise ArgumentError, "audience is required" unless audience.is_a?(String) && audience.present?
      unless verified_at.is_a?(Time) || verified_at.is_a?(ActiveSupport::TimeWithZone)
        raise ArgumentError, "verified_at must be a time"
      end
      unless verification_authority.is_a?(String) && verification_authority.present?
        raise ArgumentError, "verification_authority is required"
      end

      super(
        provider: provider.dup.freeze,
        subject: subject.dup.freeze,
        issuer: issuer.dup.freeze,
        audience: audience.dup.freeze,
        verified_at: verified_at.dup.freeze,
        verification_authority: verification_authority.dup.freeze,
      )
    end
  end
end
