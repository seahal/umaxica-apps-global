# typed: false
# frozen_string_literal: true

module SignPasskeyCeremonyDelegation
  extend ActiveSupport::Concern

  private

  def start_passkey_ceremony!(_surface:, _actor:, _session_ref:, _operation: "registration")
    passkey_ceremony_grant_token
  end

  def accept_passkey_ceremony_grant!(surface:)
    token = params[:passkey_ceremony_grant].to_s
    return false if token.blank?

    grant = IdentityPasskeyCeremonyGrant.decode(
      token,
      issuer_id: IdentityPasskeyCeremonyContract.acme_issuer_id(surface),
    )
    session[passkey_ceremony_session_key] = {
      "grant" => token,
      "transaction_id" => grant["transaction_id"],
    }
    true
  rescue IdentityPasskeyCeremonyContract::Error
    false
  end

  def finish_passkey_ceremony!(surface:, actor:, session_ref:, candidate:, challenge_id:, operation: "registration")
    grant_token = passkey_ceremony_grant_token
    return commit_settings_passkey_registration!(
      surface: surface, actor: actor,
      candidate: candidate,
    ) if grant_token.blank?

    result_token = IdentityPasskeyCeremonyResultIssuer.issue!(
      grant_token: grant_token,
      candidate: candidate,
      surface: surface,
      actor_ref: actor.public_id,
      session_ref: session_ref,
      operation: operation,
      challenge_id: challenge_id,
    )
    IdentityPasskeyCeremonyFinalCommitter.call!(
      result_token: result_token,
      actor: actor,
      session_ref: session_ref,
      surface: surface,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
    )
  end

  def commit_settings_passkey_registration!(surface:, actor:, candidate:)
    config = settings_passkey_registration_config(surface)
    attributes = {
      config.fetch(:owner_key) => actor.id,
      :webauthn_id => candidate.webauthn_id,
      :public_key => candidate.public_key,
      :sign_count => candidate.sign_count.to_i,
      config.fetch(:description_key) => candidate.description.presence || I18n.t("sign.default_passkey_description"),
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
        description_key: :description,
        audit_event_id: ClientChronicleEvent::PASSKEY_REGISTERED,
      },
      "com" => {
        record_class: VisitorPasskey,
        owner_key: :visitor_id,
        description_key: :description,
      },
      "org" => {
        record_class: OperatorPasskey,
        owner_key: :staff_id,
        description_key: :name,
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

  def passkey_ceremony_grant_token
    data = session[passkey_ceremony_session_key]
    return data["grant"] if data.respond_to?(:[]) && data["grant"].present?

    nil
  end

  def reset_passkey_ceremony_session!
    session.delete(passkey_ceremony_session_key)
  end

  def passkey_ceremony_session_key
    :passkey_ceremony
  end
end
