# typed: false
# frozen_string_literal: true

module ClientSecretCredentials
  class Create
    ACTION = "user_secret_credential.create"
    EVENT_ID = ClientChronicleEvent::USER_SECRET_CREATED

    Result = Struct.new(:secret_credential, :raw_secret_credential, keyword_init: true)

    def self.call(actor:, user:, params:, raw_secret_credential: nil)
      new(actor: actor, user: user, params: params, raw_secret_credential: raw_secret_credential).call
    end

    def initialize(actor:, user:, params:, raw_secret_credential: nil)
      @actor = actor
      @user = user
      @params = params
      @raw_secret_credential = raw_secret_credential
    end

    def call
      raw_secret_credential = @raw_secret_credential.presence || ClientSecretCredential.generate_raw_secret_credential
      secret_credential = @user.client_secret_credentials.new(name: @params[:name].to_s.strip)
      secret_credential.raw_secret_credential = raw_secret_credential
      secret_credential.password = raw_secret_credential
      secret_credential.user_secret_status_id = status_id_for(@params[:enabled])

      audit_class.transaction do
        ClientSecretCredential.transaction do
          ensure_audit_dependencies!
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
