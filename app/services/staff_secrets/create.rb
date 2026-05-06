# typed: false
# frozen_string_literal: true

module StaffSecrets
  class Create
    ACTION = "staff_secret.create"
    EVENT_ID = StaffChronicleEvent::STAFF_SECRET_CREATED

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
      raw_secret = @raw_secret.presence || StaffSecret.generate_raw_secret
      secret = @staff.staff_secrets.new(name: @params[:name].to_s.strip)
      secret.raw_secret = raw_secret
      secret.password = raw_secret
      secret.staff_secret_status_id = status_id_for(@params[:enabled])

      StaffChronicle.transaction do
        StaffSecret.transaction do
          ensure_audit_dependencies!
          secret.save!
          StaffChronicle.create!(
            actor: @actor,
            subject_type: "StaffSecret",
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
      StaffSecret.status_id_for(status)
    end

    def ensure_audit_dependencies!
      ChronicleRecord.connected_to(role: :writing) do
        StaffChronicleEvent.find_or_create_by!(id: EVENT_ID)
        StaffChronicleLevel.find_or_create_by!(id: StaffChronicleLevel::NOTHING)
      end
    end
  end
end
