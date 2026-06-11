# typed: false
# frozen_string_literal: true

module SignTelephoneCeremonyDelegation
  extend ActiveSupport::Concern

  private

  def start_telephone_ceremony!(surface:, actor:, session_ref:, candidate:, operation: "registration")
    return telephone_ceremony_grant_token if telephone_ceremony_grant_token.present?

    raise IdentityTelephoneCeremony::Error, "telephone ceremony grant is required"
  end

  def accept_telephone_ceremony_grant!(surface:)
    token = params[:telephone_ceremony_grant].to_s
    return false if token.blank?

    grant = IdentityTelephoneCeremonyGrant.decode(
      token,
      issuer_id: IdentityTelephoneCeremonyContract.acme_issuer_id(surface),
    )
    session[telephone_ceremony_session_key] = {
      "grant" => token,
      "transaction_id" => grant["transaction_id"],
    }
    true
  rescue IdentityTelephoneCeremony::Error
    false
  end

  def finish_telephone_ceremony!(surface:, actor:, session_ref:, candidate:, operation: "registration")
    grant_token = telephone_ceremony_grant_token
    raise IdentityTelephoneCeremony::Error, "telephone ceremony grant is required" if grant_token.blank?

    result_token = IdentityTelephoneCeremonyResultIssuer.issue!(
      grant_token: grant_token,
      candidate: candidate,
      surface: surface,
      actor_ref: actor.public_id,
      session_ref: session_ref,
      operation: operation,
      attempt_count: candidate.otp_attempts_count,
    )
    IdentityTelephoneCeremonyFinalCommitter.call!(
      result_token: result_token,
      actor: actor,
      session_ref: session_ref,
      surface: surface,
    )
  end

  def telephone_ceremony_grant_token
    data = session[telephone_ceremony_session_key]
    return data["grant"] if data.respond_to?(:[]) && data["grant"].present?

    nil
  end

  def reset_telephone_ceremony_session!
    session.delete(telephone_ceremony_session_key)
  end

  def telephone_ceremony_session_key
    :telephone_ceremony
  end

  def telephone_candidate_ref(candidate)
    (candidate.respond_to?(:public_id) && candidate.public_id.present?) ? candidate.public_id : candidate.id.to_s
  end
end
