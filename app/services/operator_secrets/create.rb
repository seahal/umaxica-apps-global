# typed: false
# frozen_string_literal: true

module OperatorSecrets
  class Create
    ACTION = "staff_secret.create"
    EVENT_ID = OperatorChronicleEvent::STAFF_SECRET_CREATED

    Result = Struct.new(:secret, :raw_secret, keyword_init: true)

    def self.call(actor:, staff:, params:, raw_secret: nil)
      new(actor: actor, staff: staff, params: params, raw_secret: raw_secret).call
    end

    def initialize(actor:, staff:, params:, raw_secret: nil)
      @actor = actor
      @staff = staff
      @params = params
      @raw_secret = raw_secret
    end

    def call
      raw_secret = @raw_secret.presence || OperatorSecret.generate_raw_secret
      secret = @staff.staff_secrets.new(name: @params[:name].to_s.strip)
      secret.raw_secret = raw_secret
      secret.password = raw_secret
      secret.staff_secret_status_id = status_id_for(@params[:enabled])

      OperatorChronicle.transaction do
        OperatorSecret.transaction do
          ensure_audit_dependencies!
          secret.save!
          OperatorChronicle.create!(
            actor: @actor,
            subject_type: "OperatorSecret",
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
