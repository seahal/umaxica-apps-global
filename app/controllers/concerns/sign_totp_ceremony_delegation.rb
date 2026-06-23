# typed: false
# frozen_string_literal: true

module SignTotpCeremonyDelegation
  extend ActiveSupport::Concern

  private

  def start_totp_ceremony!(_surface:, _actor:, _session_ref:, _operation: "registration")
    totp_ceremony_grant_token
  end

  def accept_totp_ceremony_grant!(surface:)
    token = params[:totp_ceremony_grant].to_s
    return false if token.blank?

    grant = IdentityTotpCeremonyGrant.decode(
      token,
      issuer_id: IdentityTotpCeremonyContract.acme_issuer_id(surface),
    )
    session[totp_ceremony_session_key] = {
      "grant" => token,
      "transaction_id" => grant["transaction_id"],
    }
    true
  rescue IdentityTotpCeremonyContract::Error
    false
  end

  def finish_totp_ceremony!(surface:, actor:, session_ref:, private_key:, title:, last_otp_at:,
                            operation: "registration")
    grant_token = totp_ceremony_grant_token
    if grant_token.blank?
      return create_settings_totp!(
        surface: surface,
        actor: actor,
        private_key: private_key,
        title: title,
        last_otp_at: last_otp_at,
      )
    end

    grant = IdentityTotpCeremonyGrant.decode(
      grant_token,
      issuer_id: IdentityTotpCeremonyContract.acme_issuer_id(surface),
    )
    candidate = IdentityTotpCeremonyCandidateStore.store!(
      surface: surface,
      actor_ref: actor.public_id,
      session_ref: session_ref,
      private_key: private_key,
      title: title,
      last_otp_at: last_otp_at,
      expires_at: Time.zone.at(grant["exp"].to_i),
    )
    result_token = IdentityTotpCeremonyResultIssuer.issue!(
      grant_token: grant_token,
      candidate: candidate,
      surface: surface,
      actor_ref: actor.public_id,
      session_ref: session_ref,
      operation: operation,
      challenge_id: candidate.ref,
    )
    IdentityTotpCeremonyFinalCommitter.call!(
      result_token: result_token,
      actor: actor,
      session_ref: session_ref,
      surface: surface,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
    )
  end

  def create_settings_totp!(surface:, actor:, private_key:, title:, last_otp_at:)
    raise IdentityTotpCeremonyContract::Error, "surface is invalid" unless surface.to_s == "app"

    totp = actor.client_totp_credentials.create!(
      private_key: private_key,
      last_otp_at: last_otp_at,
      title: title,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    IdentityAudit.record!(
      actor: actor,
      event_id: ClientChronicleEvent::TOTP_ENABLED,
      action: "totp.enable",
      subject: totp,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
    )
    Struct.new(:totp).new(totp)
  end

  def totp_ceremony_grant_token
    data = session[totp_ceremony_session_key]
    return data["grant"] if data.respond_to?(:[]) && data["grant"].present?

    nil
  end

  def reset_totp_ceremony_session!
    session.delete(totp_ceremony_session_key)
  end

  def totp_ceremony_session_key
    :totp_ceremony
  end
end
