# typed: false
# frozen_string_literal: true

module SignSettingsPasskeyRegistration
  extend ActiveSupport::Concern

  private

  # Keyword names are part of this seam's contract, so they match
  # #finish_passkey_ceremony! rather than carrying underscore prefixes: a caller
  # that spells them without the prefix must not raise ArgumentError.
  def start_passkey_ceremony!(surface:, actor:, session_ref:, operation: "registration") # rubocop:disable Lint/UnusedMethodArgument
    nil
  end

  def finish_passkey_ceremony!(surface:, actor:, session_ref:, candidate:, challenge_id:, operation: "registration") # rubocop:disable Lint/UnusedMethodArgument
    commit_settings_passkey_registration!(
      surface: surface, actor: actor,
      candidate: candidate,
    )
  end

  def commit_settings_passkey_registration!(surface:, actor:, candidate:)
    config = settings_passkey_registration_config(surface)
    attributes = {
      config.fetch(:owner_key) => actor.id,
      :webauthn_id => candidate.webauthn_id,
      :public_key => candidate.public_key,
      :sign_count => candidate.sign_count.to_i,
      :description => candidate.description.presence || I18n.t("sign.default_passkey_description"),
      **Webauthn::AuthenticatorMetadata.permit(candidate.metadata),
    }
    passkey = config.fetch(:record_class).create!(attributes)
    record_settings_passkey_registration_audit!(config, actor, passkey)
    Struct.new(:passkey).new(passkey)
  rescue ActiveRecord::RecordNotUnique => e
    raise IdentityPasskeyCeremonyContract::Error, "passkey credential is already registered: #{e.message}"
  end

  def settings_passkey_registration_config(surface)
    {
      "app" => {
        record_class: ClientPasskey,
        owner_key: :user_id,
        audit_event_id: ClientChronicleEvent::PASSKEY_REGISTERED,
      },
      "com" => {
        record_class: VisitorPasskey,
        owner_key: :visitor_id,
      },
      "org" => {
        record_class: OperatorPasskey,
        owner_key: :staff_id,
        audit_event_id: OperatorChronicleEvent::PASSKEY_REGISTERED,
      },
    }.fetch(surface.to_s) { raise IdentityPasskeyCeremonyContract::Error, "surface is invalid" }
  end

  def record_settings_passkey_registration_audit!(config, actor, passkey)
    return if config[:audit_event_id].blank?

    IdentityAudit.record!(
      actor: actor,
      event_id: config.fetch(:audit_event_id),
      action: "passkey.register",
      subject: passkey,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
    )
  end

  def reset_passkey_ceremony_session!
    session.delete(passkey_ceremony_session_key)
  end

  def passkey_ceremony_session_key
    :passkey_ceremony
  end
end
