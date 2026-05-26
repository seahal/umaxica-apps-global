# typed: false
# frozen_string_literal: true

module Sign
  module App
    class SessionRevokeAudit
      EVENT_ID = ClientChronicleEvent::SESSION_REVOKED

      def self.record!(actor:, revoked_session_count:, action:, ip_address:, user_agent:)
        return if revoked_session_count.to_i <= 0

        Identity::Audit.record!(
          actor: actor,
          event_id: EVENT_ID,
          action: action,
          ip_address: ip_address,
          user_agent: user_agent,
          metadata: { revoked_session_count: revoked_session_count },
        )
      end
    end
  end
end
