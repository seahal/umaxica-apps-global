# typed: false
# frozen_string_literal: true

module SignTotpCeremonyDelegation
  extend ActiveSupport::Concern

  private

  def start_totp_ceremony!(surface:, actor:, session_ref:, operation: "registration")
    return if totp_ceremony_grant_token.present?

    issuance = IdentityTotpCeremonyGrantIssuer.issue!(
      surface: surface,
      actor_ref: actor.public_id,
      session_ref: session_ref,
      operation: operation,
    )
    session[totp_ceremony_session_key] = {
      "grant" => issuance.grant,
      "transaction_id" => issuance.transaction.transaction_id,
    }
    issuance
  end

  def accept_totp_ceremony_grant!(surface:)
    token = params[:totp_ceremony_grant].to_s
    return true if token.blank?

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
      grant_token = start_totp_ceremony!(
        surface: surface,
        actor: actor,
        session_ref: session_ref,
        operation: operation,
      ).grant
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
