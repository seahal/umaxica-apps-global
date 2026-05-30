# typed: false
# frozen_string_literal: true

module ClientSecretCredentials
  class Update
    ACTION = "user_secret_credential.update"
    EVENT_ID = ClientChronicleEvent::USER_SECRET_UPDATED

    Result = Struct.new(:secret_credential, keyword_init: true)

    def self.call(actor:, secret_credential:, params:)
      new(actor: actor, secret_credential: secret_credential, params: params).call
    end

    def initialize(actor:, secret_credential:, params:)
      @actor = actor
      @secret_credential = secret_credential
      @params = params
    end

    def call
      @secret_credential.name = @params[:name].to_s.strip if @params[:name].present?
      @secret_credential.user_secret_status_id = status_id_for(@params[:enabled]) if @params.key?(:enabled)

      audit_class.transaction do
        ClientSecretCredential.transaction do
          ensure_audit_dependencies!
          @secret_credential.save!
          audit_class.create!(
            actor: @actor,
            subject_type: "ClientSecretCredential",
            subject_id: @secret_credential.id.to_s,
            event_id: EVENT_ID,
            occurred_at: Time.current,
            context: { action: ACTION },
          )
        end
      end

      Result.new(secret_credential: @secret_credential)
    end

    private

    def audit_class
      @audit_class ||= @actor.is_a?(Operator) ? OperatorChronicle : ClientChronicle
    end

    def status_id_for(enabled_param)
      enabled = ActiveModel::Type::Boolean.new.cast(enabled_param)
      status = enabled ? :active : :revoked
      ClientSecretCredential.status_id_for(status)
    end

    def ensure_audit_dependencies!
      ChronicleRecord.connected_to(role: :writing) do
        ClientChronicleEvent.find_or_create_by!(id: EVENT_ID)
        ClientChronicleLevel.find_or_create_by!(id: ClientChronicleLevel::NOTHING)
      end
    end
  end
end
