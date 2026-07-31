# typed: false
# frozen_string_literal: true

class ExternalAuthenticationAppleNotificationProcessor
  def self.call(...)
    new(...).call
  end

  def initialize(event:)
    raise ArgumentError, "event is required" unless event.is_a?(ClientAppleNotificationEvent)

    @event = event
  end

  def call
    return event if event.terminal?

    transition_applied =
      case event.event_type
      when "consent-revoked" then apply_consent_revocation!
      when "account-deleted" then apply_account_deletion!
      else false
      end

    revoke_sessions! if transition_applied
    event.complete!
    event
  end

  private

  attr_reader :event

  def apply_consent_revocation!
    return apply_common_transition!("consent_revoked") if event.client_external_identity

    false
  end

  def apply_account_deletion!
    return apply_common_transition!("account_deleted") if event.client_external_identity

    false
  end

  def apply_common_transition!(target_state)
    identity = event.client_external_identity
    return false if identity.state == "account_deleted"
    return false if identity.last_provider_event_at && identity.last_provider_event_at >= event.occurred_at

    identity.update!(state: target_state, last_provider_event_at: event.occurred_at)
    true
  end

  def revoke_sessions!
    return unless event.client

    AuthenticationLogoutAllSessions.call(
      resource: event.client,
      reason: "apple_#{event.event_type.tr("-", "_")}",
    )
  end
end
