# typed: false
# frozen_string_literal: true

class ClientSecretCredentialsDestroy
  ACTION = "user_secret_credential.delete"
  EVENT_ID = ClientChronicleEvent::USER_SECRET_REMOVED

  def self.call(actor:, secret_credential:)
    new(actor: actor, secret_credential: secret_credential).call
  end

  def initialize(actor:, secret_credential:)
    @actor = actor
    @secret_credential = secret_credential
  end

  def call
    audit_class.transaction do
      ClientSecretCredential.transaction do
        ensure_audit_dependencies!
        @secret_credential.discard_now!(purge_after: 1.day)
        @secret_credential.user_secret_status_id = ClientSecretCredential.status_id_for(:deleted)
        audit_class.create!(
          actor: @actor,
          subject_type: "ClientSecretCredential",
          subject_id: @secret_credential.id.to_s,
          event_id: EVENT_ID,
          occurred_at: Time.current,
          context: { action: ACTION },
        )
        @secret_credential.save!
        CredentialSecurityTransition.call(
          actor: @actor,
          current_session: nil,
          reason: :secret_credential_changed,
          affected_surface: "app",
          revoke_current: true,
        )
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
