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
    return false unless event.client_apple_identity
    return false if event.client_apple_identity.status_id == ClientAppleIdentityStatus::DELETED
    return false if legacy_event_is_stale?

    event.client_apple_identity.update!(
      status_id: ClientAppleIdentityStatus::REVOKED,
      refresh_token: "",
    )
    true
  end

  def apply_account_deletion!
    return apply_common_transition!("account_deleted") if event.client_external_identity
    return false unless event.client_apple_identity
    return false if legacy_event_is_stale?

    event.client_apple_identity.update!(
      status_id: ClientAppleIdentityStatus::DELETED,
      refresh_token: "",
    )
    true
  end

  def apply_common_transition!(target_state)
    identity = event.client_external_identity
    return false if identity.state == "account_deleted"
    return false if identity.last_provider_event_at && identity.last_provider_event_at >= event.occurred_at

    identity.update!(state: target_state, last_provider_event_at: event.occurred_at)
    identity.client_apple_identity_credential&.update!(state: target_state, refresh_token: "")
    true
  end

  def legacy_event_is_stale?
    ClientAppleNotificationEvent
      .where(client_apple_identity: event.client_apple_identity)
      .where(event_type: %w(consent-revoked account-deleted), status: "completed")
      .where.not(id: event.id)
      .exists?(occurred_at: event.occurred_at..)
  end

  def revoke_sessions!
    return unless event.client

    AuthenticationLogoutAllSessions.call(
      resource: event.client,
      reason: "apple_#{event.event_type.tr("-", "_")}",
    )
  end
end
