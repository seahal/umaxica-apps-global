# typed: false
# frozen_string_literal: true

module OperatorSecrets
  class Destroy
    ACTION = "staff_secret.delete"
    EVENT_ID = OperatorChronicleEvent::STAFF_SECRET_REMOVED

    def self.call(actor:, secret:)
      new(actor: actor, secret: secret).call
    end

    def initialize(actor:, secret:)
      @actor = actor
      @secret = secret
    end

    def call
      OperatorChronicle.transaction do
        OperatorSecret.transaction do
          ensure_audit_dependencies!
          OperatorChronicle.create!(
            actor: @actor,
            subject_type: "OperatorSecret",
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
        OperatorChronicleEvent.find_or_create_by!(id: EVENT_ID)
        OperatorChronicleLevel.find_or_create_by!(id: OperatorChronicleLevel::NOTHING)
      end
    end
  end
end
