# typed: false
# frozen_string_literal: true

module StaffSecrets
  class Destroy
    ACTION = "staff_secret.delete"
    EVENT_ID = StaffChronicleEvent::STAFF_SECRET_REMOVED

    def self.call(actor:, secret:)
      new(actor: actor, secret: secret).call
    end

    def initialize(actor:, secret:)
      @actor = actor
      @secret = secret
    end

    def call
      StaffChronicle.transaction do
        StaffSecret.transaction do
          ensure_audit_dependencies!
          StaffChronicle.create!(
            actor: @actor,
            subject_type: "StaffSecret",
            subject_id: @secret.id.to_s,
            event_id: EVENT_ID,
            occurred_at: Time.current,
            context: { action: ACTION },
          )
          @secret.destroy!
        end
      end
    end

    private

    def ensure_audit_dependencies!
      ChronicleRecord.connected_to(role: :writing) do
        StaffChronicleEvent.find_or_create_by!(id: EVENT_ID)
        StaffChronicleLevel.find_or_create_by!(id: StaffChronicleLevel::NOTHING)
      end
    end
  end
end
