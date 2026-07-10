# typed: false
# frozen_string_literal: true

class SignAppSessionRevokeAudit
  EVENT_ID = ClientChronicleEvent::SESSION_REVOKED

  def self.record!(actor:, revoked_session_count:, action:, ip_address:, user_agent:)
    return if revoked_session_count.to_i <= 0

    IdentityAudit.record!(
      actor: actor,
      event_id: EVENT_ID,
      action: action,
      ip_address: ip_address,
      user_agent: user_agent,
      metadata: { revoked_session_count: revoked_session_count },
    )
  end
end
