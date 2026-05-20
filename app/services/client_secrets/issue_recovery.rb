# typed: false
# frozen_string_literal: true

module ClientSecrets
  class IssueRecovery
    ACTION = "user_secret.recovery_issue"
    EVENT_ID = ClientChronicleEvent::RECOVERY_CODES_GENERATED

    Result = Struct.new(:secret, :raw_secret, keyword_init: true)

    def self.call(actor:, user:)
      new(actor: actor, user: user).call
    end

    def initialize(actor:, user:)
      @actor = actor
      @user = user
    end

    def call
      raw_secret = ClientSecret.generate_raw_secret
      secret = nil

      audit_class.transaction do
        ClientSecret.transaction do
          ensure_secret_reference_data!
          ensure_audit_dependencies!
          revoke_existing_recovery_secrets!

          secret = @user.client_secrets.new(
            name: raw_secret.first(4),
            user_secret_kind_id: ClientSecretKind::RECOVERY,
            user_secret_status_id: ClientSecretStatus::ACTIVE,
          )
          secret.password = raw_secret
          secret.save!

          audit_class.create!(
            actor: @actor,
            subject_type: "ClientSecret",
            subject_id: secret.id.to_s,
            event_id: EVENT_ID,
            occurred_at: Time.current,
            context: { action: ACTION },
          )
        end
      end

      Result.new(secret: secret, raw_secret: raw_secret)
    end

    private

    def audit_class
      @audit_class ||= @actor.is_a?(Operator) ? OperatorChronicle : ClientChronicle
    end

    def revoke_existing_recovery_secrets!
      @user.client_secrets.where(user_secret_kind_id: ClientSecretKind::RECOVERY)
        .where(user_identity_secret_status_id: ClientSecretStatus::ACTIVE)
        .find_each do |secret|
        secret.update!(user_identity_secret_status_id: ClientSecretStatus::REVOKED)
      end
    end

    def ensure_secret_reference_data!
      ClientSecretKind.ensure_defaults!
      ClientSecretStatus.ensure_defaults!
    end

    def ensure_audit_dependencies!
      ChronicleRecord.connected_to(role: :writing) do
        ClientChronicleEvent.find_or_create_by!(id: EVENT_ID)
        ClientChronicleLevel.find_or_create_by!(id: ClientChronicleLevel::NOTHING)
      end
    end
  end
end
