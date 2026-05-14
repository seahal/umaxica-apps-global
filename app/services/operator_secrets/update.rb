# typed: false
# frozen_string_literal: true

module OperatorSecrets
  class Update
    ACTION = "staff_secret.update"
    EVENT_ID = OperatorChronicleEvent::STAFF_SECRET_UPDATED

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
      @secret.staff_secret_status_id = status_id_for(@params[:enabled]) if @params.key?(:enabled)

      OperatorChronicle.transaction do
        OperatorSecret.transaction do
          ensure_audit_dependencies!
          @secret.save!
          OperatorChronicle.create!(
            actor: @actor,
            subject_type: "OperatorSecret",
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

    def status_id_for(enabled_param)
      enabled = ActiveModel::Type::Boolean.new.cast(enabled_param)
      status = enabled ? :active : :revoked
      OperatorSecret.status_id_for(status)
    end

    def ensure_audit_dependencies!
      ChronicleRecord.connected_to(role: :writing) do
        OperatorChronicleEvent.find_or_create_by!(id: EVENT_ID)
        OperatorChronicleLevel.find_or_create_by!(id: OperatorChronicleLevel::NOTHING)
      end
    end
  end
end
