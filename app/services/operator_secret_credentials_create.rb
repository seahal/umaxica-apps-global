# typed: false
# frozen_string_literal: true

class OperatorSecretCredentialsCreate
  ACTION = "staff_secret_credential.create"
  EVENT_ID = OperatorChronicleEvent::STAFF_SECRET_CREATED

  Result = Struct.new(:secret_credential, :raw_secret_credential, keyword_init: true)

  def self.call(actor:, staff:, params:, raw_secret_credential: nil)
    new(actor: actor, staff: staff, params: params, raw_secret_credential: raw_secret_credential).call
  end

  def initialize(actor:, staff:, params:, raw_secret_credential: nil)
    @actor = actor
    @staff = staff
    @params = params
    @raw_secret_credential = raw_secret_credential
  end

  def call
    raw_secret_credential = @raw_secret_credential.presence || OperatorSecretCredential.generate_raw_secret_credential
    secret_credential = @staff.staff_secret_credentials.new(name: @params[:name].to_s.strip)
    secret_credential.raw_secret_credential = raw_secret_credential
    secret_credential.password = raw_secret_credential
    secret_credential.staff_secret_status_id = status_id_for(@params[:enabled])

    OperatorChronicle.transaction do
      OperatorSecretCredential.transaction do
        ensure_audit_dependencies!
        secret_credential.save!
        OperatorChronicle.create!(
          actor: @actor,
          subject_type: "OperatorSecretCredential",
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

  def status_id_for(enabled_param)
    enabled = ActiveModel::Type::Boolean.new.cast(enabled_param)
    status = enabled ? :active : :revoked
    OperatorSecretCredential.status_id_for(status)
  end

  def ensure_audit_dependencies!
    ChronicleRecord.connected_to(role: :writing) do
      OperatorChronicleEvent.find_or_create_by!(id: EVENT_ID)
      OperatorChronicleLevel.find_or_create_by!(id: OperatorChronicleLevel::NOTHING)
    end
  end
end
