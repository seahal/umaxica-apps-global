# typed: false
# frozen_string_literal: true

module OperatorSecretCredentials
  class Destroy
    ACTION = "staff_secret_credential.delete"
    EVENT_ID = OperatorChronicleEvent::STAFF_SECRET_REMOVED

    def self.call(actor:, secret_credential:)
      new(actor: actor, secret_credential: secret_credential).call
    end

    def initialize(actor:, secret_credential:)
      @actor = actor
      @secret_credential = secret_credential
    end

    def call
      OperatorChronicle.transaction do
        OperatorSecretCredential.transaction do
          ensure_audit_dependencies!
          OperatorChronicle.create!(
            actor: @actor,
            subject_type: "OperatorSecretCredential",
            subject_id: @secret_credential.id.to_s,
            event_id: EVENT_ID,
            occurred_at: Time.current,
            context: { action: ACTION },
          )
          @secret_credential.destroy!
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
