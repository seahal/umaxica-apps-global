# typed: false
# frozen_string_literal: true

module SignEmailCeremonyDelegation
  private

  def start_email_ceremony!(surface:, actor:, session_ref:, candidate:, operation: "registration")
    return email_ceremony_grant_token if email_ceremony_grant_token.present?

    raise IdentityEmailCeremonyContract::Error, "email ceremony grant is required"
  end

  def accept_email_ceremony_grant!(surface:)
    token = params[:email_ceremony_grant].to_s
    return false if token.blank?

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
    raise IdentityEmailCeremonyContract::Error, "email ceremony grant is required" if grant_token.blank?

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
