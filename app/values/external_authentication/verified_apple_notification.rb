# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  class VerifiedAppleNotification < Data.define(:jti, :event_type, :subject, :issued_at, :occurred_at)
    EVENT_TYPES = %w(email-enabled email-disabled consent-revoked account-deleted).freeze

    def initialize(jti:, event_type:, subject:, issued_at:, occurred_at:)
      raise ArgumentError, "jti is required" unless jti.is_a?(String) && jti.present?
      raise ArgumentError, "event type is unsupported" unless EVENT_TYPES.include?(event_type)
      raise ArgumentError, "subject is required" unless subject.is_a?(String) && subject.present?
      raise ArgumentError, "issued_at must be a time" unless issued_at.is_a?(Time)
      raise ArgumentError, "occurred_at must be a time" unless occurred_at.is_a?(Time)

      super(
        jti: jti.dup.freeze,
        event_type: event_type.dup.freeze,
        subject: subject.dup.freeze,
        issued_at: issued_at.dup.freeze,
        occurred_at: occurred_at.dup.freeze,
      )
    end
  end
end
