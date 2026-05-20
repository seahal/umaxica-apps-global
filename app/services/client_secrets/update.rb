# typed: false
# frozen_string_literal: true

module ClientSecrets
  class Update
    ACTION = "user_secret.update"
    EVENT_ID = ClientChronicleEvent::USER_SECRET_UPDATED

    Result = Struct.new(:secret, keyword_init: true)

    def self.call(actor:, secret:, params:)
      new(actor: actor, secret: secret, params: params).call
    end

    def initialize(actor:, secret:, params:)
      @actor = actor
      @secret = secret
      @params = params
    end

    def call
      @secret.name = @params[:name].to_s.strip if @params[:name].present?
      @secret.user_secret_status_id = status_id_for(@params[:enabled]) if @params.key?(:enabled)

      audit_class.transaction do
        ClientSecret.transaction do
          ensure_audit_dependencies!
          @secret.save!
          audit_class.create!(
            actor: @actor,
            subject_type: "ClientSecret",
            subject_id: @secret.id.to_s,
            event_id: EVENT_ID,
            occurred_at: Time.current,
            context: { action: ACTION },
          )
        end
      end

      Result.new(secret: @secret)
    end

    private

    def audit_class
      @audit_class ||= @actor.is_a?(Operator) ? OperatorChronicle : ClientChronicle
    end

    def status_id_for(enabled_param)
      enabled = ActiveModel::Type::Boolean.new.cast(enabled_param)
      status = enabled ? :active : :revoked
      ClientSecret.status_id_for(status)
    end

    def ensure_audit_dependencies!
      ChronicleRecord.connected_to(role: :writing) do
        ClientChronicleEvent.find_or_create_by!(id: EVENT_ID)
        ClientChronicleLevel.find_or_create_by!(id: ClientChronicleLevel::NOTHING)
      end
    end
  end
end
