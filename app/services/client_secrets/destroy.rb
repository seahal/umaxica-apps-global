# typed: false
# frozen_string_literal: true

module ClientSecrets
  class Destroy
    ACTION = "user_secret.delete"
    EVENT_ID = ClientChronicleEvent::USER_SECRET_REMOVED

    def self.call(actor:, secret:)
      new(actor: actor, secret: secret).call
    end

    def initialize(actor:, secret:)
      @actor = actor
      @secret = secret
    end

    def call
      audit_class.transaction do
        ClientSecret.transaction do
          ensure_audit_dependencies!
          audit_class.create!(
            actor: @actor,
            subject_type: "ClientSecret",
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
      @audit_class ||= @actor.is_a?(Operator) ? OperatorChronicle : ClientChronicle
    end

    def ensure_audit_dependencies!
      ChronicleRecord.connected_to(role: :writing) do
        ClientChronicleEvent.find_or_create_by!(id: EVENT_ID)
        ClientChronicleLevel.find_or_create_by!(id: ClientChronicleLevel::NOTHING)
      end
    end
  end
end
