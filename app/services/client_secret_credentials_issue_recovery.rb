# typed: false
# frozen_string_literal: true

class ClientSecretCredentialsIssueRecovery
  ACTION = "user_secret_credential.recovery_issue"
  EVENT_ID = ClientChronicleEvent::RECOVERY_CODES_GENERATED

  Result = Struct.new(:secret_credential, :raw_secret_credential, keyword_init: true)

  def self.call(actor:, user:)
    new(actor: actor, user: user).call
  end

  def initialize(actor:, user:)
    @actor = actor
    @user = user
  end

  def call
    raw_secret_credential = ClientSecretCredential.generate_raw_secret_credential
    secret_credential = nil

    audit_class.transaction do
      ClientSecretCredential.transaction do
        ensure_secret_credential_reference_data!
        ensure_audit_dependencies!
        revoke_existing_recovery_secret_credentials!

        secret_credential = @user.client_secret_credentials.new(
          name: raw_secret_credential.first(4),
          user_secret_kind_id: ClientSecretCredentialKind::RECOVERY,
          user_secret_status_id: ClientSecretCredentialStatus::ACTIVE,
        )
        secret_credential.password = raw_secret_credential
        secret_credential.save!

        audit_class.create!(
          actor: @actor,
          subject_type: "ClientSecretCredential",
          subject_id: secret_credential.id.to_s,
          event_id: EVENT_ID,
          occurred_at: Time.current,
          context: { action: ACTION },
        )
      end
    end

    Result.new(secret_credential: secret_credential, raw_secret_credential: raw_secret_credential)
  end

  private

  def audit_class
    @audit_class ||= @actor.is_a?(Operator) ? OperatorChronicle : ClientChronicle
  end

  def revoke_existing_recovery_secret_credentials!
    @user.client_secret_credentials.where(user_secret_kind_id: ClientSecretCredentialKind::RECOVERY)
      .where(user_identity_secret_status_id: ClientSecretCredentialStatus::ACTIVE)
      .find_each do |secret_credential|
      secret_credential.update!(user_identity_secret_status_id: ClientSecretCredentialStatus::REVOKED)
    end
  end

  def ensure_secret_credential_reference_data!
    ClientSecretCredentialKind.ensure_defaults!
    ClientSecretCredentialStatus.ensure_defaults!
  end

  def ensure_audit_dependencies!
    ChronicleRecord.connected_to(role: :writing) do
      ClientChronicleEvent.find_or_create_by!(id: EVENT_ID)
      ClientChronicleLevel.find_or_create_by!(id: ClientChronicleLevel::NOTHING)
    end
  end
end
