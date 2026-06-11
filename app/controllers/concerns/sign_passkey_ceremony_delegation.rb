# typed: false
# frozen_string_literal: true

module SignPasskeyCeremonyDelegation
  extend ActiveSupport::Concern

  private

  def start_passkey_ceremony!(surface:, actor:, session_ref:, operation: "registration")
    return passkey_ceremony_grant_token if passkey_ceremony_grant_token.present?

    raise IdentityPasskeyCeremonyContract::Error, "passkey ceremony grant is required"
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
    raise IdentityPasskeyCeremonyContract::Error, "passkey ceremony grant is required" if grant_token.blank?

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
