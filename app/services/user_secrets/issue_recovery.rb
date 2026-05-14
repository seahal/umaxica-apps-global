# typed: false
# frozen_string_literal: true

module UserSecrets
  class IssueRecovery
    ACTION = "user_secret.recovery_issue"
    EVENT_ID = UserChronicleEvent::RECOVERY_CODES_GENERATED

    Result = Struct.new(:secret, :raw_secret, keyword_init: true)

    def self.call(actor:, user:)
      new(actor: actor, user: user).call
    end

    def initialize(actor:, user:)
      @actor = actor
      @user = user
    end

    def call
      raw_secret = UserSecret.generate_raw_secret
      secret = nil

      audit_class.transaction do
        UserSecret.transaction do
          ensure_audit_dependencies!
          revoke_existing_recovery_secrets!

          secret = @user.user_secrets.new(
            name: raw_secret.first(4),
            user_secret_kind_id: UserSecretKind::RECOVERY,
            user_secret_status_id: UserSecretStatus::ACTIVE,
          )
          secret.password = raw_secret
          secret.save!

          audit_class.create!(
            actor: @actor,
            subject_type: "UserSecret",
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
      @audit_class ||= @actor.is_a?(Operator) ? OperatorChronicle : UserChronicle
    end

    def revoke_existing_recovery_secrets!
      @user.user_secrets.where(user_secret_kind_id: UserSecretKind::RECOVERY)
        .where(user_identity_secret_status_id: UserSecretStatus::ACTIVE)
        .find_each do |secret|
        secret.update!(user_identity_secret_status_id: UserSecretStatus::REVOKED)
      end
    end

    def ensure_audit_dependencies!
      ChronicleRecord.connected_to(role: :writing) do
        UserChronicleEvent.find_or_create_by!(id: EVENT_ID)
        UserChronicleLevel.find_or_create_by!(id: UserChronicleLevel::NOTHING)
      end
    end
  end
end
