# typed: false
# frozen_string_literal: true

module Sign
  module App
    class SessionRevokeAudit
      EVENT_ID = ClientChronicleEvent::SESSION_REVOKED

      def self.record!(actor:, revoked_session_count:, action:, ip_address:, user_agent:)
        return if revoked_session_count.to_i <= 0

        ChronicleRecord.connected_to(role: :writing) do
          ClientChronicleEvent.find_or_create_by!(id: EVENT_ID)
          ClientChronicleLevel.find_or_create_by!(id: ClientChronicleLevel::NOTHING)

          ClientChronicle.create!(
            actor: actor,
            subject_type: "Client",
            subject_id: actor.id,
            event_id: EVENT_ID,
            level_id: ClientChronicleLevel::NOTHING,
            occurred_at: Time.current,
            ip_address: ip_address,
            context: {
              action: action,
              revoked_session_count: revoked_session_count,
              user_agent: user_agent,
            }.compact,
          )
        end
      end
    end
  end
end
