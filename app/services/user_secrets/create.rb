# typed: false
# frozen_string_literal: true

module UserSecrets
  class Create
    ACTION = "user_secret.create"
    EVENT_ID = UserChronicleEvent::USER_SECRET_CREATED

    Result = Struct.new(:secret, :raw_secret, keyword_init: true)

    def self.call(actor:, user:, params:, raw_secret: nil)
      new(actor: actor, user: user, params: params, raw_secret: raw_secret).call
    end

    def initialize(actor:, user:, params:, raw_secret: nil)
      @actor = actor
      @user = user
      @params = params
      @raw_secret = raw_secret
    end

    def call
      raw_secret = @raw_secret.presence || UserSecret.generate_raw_secret
      secret = @user.user_secrets.new(name: @params[:name].to_s.strip)
      secret.raw_secret = raw_secret
      secret.password = raw_secret
      secret.user_secret_status_id = status_id_for(@params[:enabled])

      audit_class.transaction do
        UserSecret.transaction do
          ensure_audit_dependencies!
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

    def status_id_for(enabled_param)
      enabled = ActiveModel::Type::Boolean.new.cast(enabled_param)
      status = enabled ? :active : :revoked
      UserSecret.status_id_for(status)
    end

    def ensure_audit_dependencies!
      ChronicleRecord.connected_to(role: :writing) do
        UserChronicleEvent.find_or_create_by!(id: EVENT_ID)
        UserChronicleLevel.find_or_create_by!(id: UserChronicleLevel::NOTHING)
      end
    end
  end
end
