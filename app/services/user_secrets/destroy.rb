# typed: false
# frozen_string_literal: true

module UserSecrets
  class Destroy
    ACTION = "user_secret.delete"
    EVENT_ID = UserChronicleEvent::USER_SECRET_REMOVED

    def self.call(actor:, secret:)
      new(actor: actor, secret: secret).call
    end

    def initialize(actor:, secret:)
      @actor = actor
      @secret = secret
    end

    def call
      audit_class.transaction do
        UserSecret.transaction do
          ensure_audit_dependencies!
          audit_class.create!(
            actor: @actor,
            subject_type: "UserSecret",
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

    def audit_class
      @audit_class ||= @actor.is_a?(Operator) ? OperatorChronicle : UserChronicle
    end

    def ensure_audit_dependencies!
      ChronicleRecord.connected_to(role: :writing) do
        UserChronicleEvent.find_or_create_by!(id: EVENT_ID)
        UserChronicleLevel.find_or_create_by!(id: UserChronicleLevel::NOTHING)
      end
    end
  end
end
