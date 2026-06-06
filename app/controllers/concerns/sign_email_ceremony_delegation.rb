# typed: false
# frozen_string_literal: true

module SignEmailCeremonyDelegation
  private

  def start_email_ceremony!(surface:, actor:, session_ref:, candidate:, operation: "registration")
    return if email_ceremony_grant_token.present?

    issuance = IdentityEmailCeremonyGrantIssuer.issue!(
      surface: surface,
      actor_ref: actor.public_id,
      session_ref: session_ref,
      operation: operation,
      email_candidate_ref: email_candidate_ref(candidate),
      normalized_email_digest: candidate.address_digest,
    )
    session[email_ceremony_session_key] = {
      "grant" => issuance.grant,
      "transaction_id" => issuance.transaction.transaction_id,
    }
    issuance.grant
  end

  def accept_email_ceremony_grant!(surface:)
    token = params[:email_ceremony_grant].to_s
    return true if token.blank?

    grant = IdentityEmailCeremonyGrant.decode(
      token,
      issuer_id: IdentityEmailCeremonyContract.acme_issuer_id(surface),
    )
    session[email_ceremony_session_key] = {
      "grant" => token,
      "transaction_id" => grant["transaction_id"],
    }
    true
  rescue IdentityEmailCeremonyContract::Error
    false
  end

  def finish_email_ceremony!(surface:, actor:, session_ref:, candidate:, operation: "registration")
    grant_token = email_ceremony_grant_token
    if grant_token.blank?
      grant_token = start_email_ceremony!(
        surface: surface,
        actor: actor,
        session_ref: session_ref,
        candidate: candidate,
        operation: operation,
      )
    end

    result_token = IdentityEmailCeremonyResultIssuer.issue!(
      grant_token: grant_token,
      candidate: candidate,
      surface: surface,
      actor_ref: actor.public_id,
      session_ref: session_ref,
      operation: operation,
      attempt_count: candidate.otp_attempts_count,
    )

    IdentityEmailCeremonyFinalCommitter.call!(
      result_token: result_token,
      actor: actor,
      session_ref: session_ref,
      surface: surface,
    )
  end

  def email_ceremony_grant_token
    data = session[email_ceremony_session_key]
    return nil if data.blank?

    data["grant"] || data[:grant]
  end

  def reset_email_ceremony_session!
    session.delete(email_ceremony_session_key)
  end

  def email_ceremony_session_key
    :email_ceremony
  end

  def email_candidate_ref(candidate)
    (candidate.respond_to?(:public_id) && candidate.public_id.present?) ? candidate.public_id : candidate.id.to_s
  end
end
