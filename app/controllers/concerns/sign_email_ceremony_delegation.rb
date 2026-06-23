# typed: false
# frozen_string_literal: true

module SignEmailCeremonyDelegation
  private

  def start_email_ceremony!(surface:, actor:, session_ref:, candidate:, operation: "registration") # rubocop:disable Lint/UnusedMethodArgument
    email_ceremony_grant_token
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
    return commit_settings_email_registration!(
      surface: surface, actor: actor,
      candidate: candidate,
    ) if grant_token.blank?

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

  def commit_settings_email_registration!(surface:, actor:, candidate:)
    config = settings_email_registration_config(surface)
    config.fetch(:record_class).transaction do
      locked = config.fetch(:record_class).lock.find(candidate.id)
      raise IdentityEmailCeremonyContract::Error,
            "email candidate owner changed" unless locked.public_send(config.fetch(:owner_key)) == actor.id
      raise IdentityEmailCeremonyContract::Error,
            "email candidate is already verified" unless locked.public_send(config.fetch(:status_key)) ==
              config.fetch(:unverified_status)

      locked.update!(config.fetch(:status_key) => config.fetch(:verified_status))
      record_settings_email_registration_audit!(config, actor, locked)
      locked
    end
  end

  def settings_email_registration_config(surface)
    {
      "app" => {
        record_class: ClientEmail,
        owner_key: :user_id,
        status_key: :user_email_status_id,
        unverified_status: ClientEmailStatus::UNVERIFIED,
        verified_status: ClientEmailStatus::VERIFIED,
        audit_event_id: ClientChronicleEvent::EMAIL_REGISTERED,
      },
      "com" => {
        record_class: VisitorEmail,
        owner_key: :visitor_id,
        status_key: :visitor_email_status_id,
        unverified_status: VisitorEmailStatus::UNVERIFIED,
        verified_status: VisitorEmailStatus::VERIFIED,
      },
      "org" => {
        record_class: OperatorEmail,
        owner_key: :staff_id,
        status_key: :staff_email_status_id,
        unverified_status: OperatorEmailStatus::UNVERIFIED,
        verified_status: OperatorEmailStatus::VERIFIED,
      },
    }.fetch(surface.to_s) { raise IdentityEmailCeremonyContract::Error, "surface is invalid" }
  end

  def record_settings_email_registration_audit!(config, actor, email)
    return if config[:audit_event_id].blank?

    IdentityAudit.record!(
      actor: actor,
      event_id: config.fetch(:audit_event_id),
      action: "email.register",
      subject: email,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
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
