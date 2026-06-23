# typed: false
# frozen_string_literal: true

module SignTelephoneCeremonyDelegation
  extend ActiveSupport::Concern

  private

  def start_telephone_ceremony!(surface:, actor:, session_ref:, candidate:, operation: "registration") # rubocop:disable Lint/UnusedMethodArgument
    telephone_ceremony_grant_token
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
    return commit_settings_telephone_registration!(
      surface: surface, actor: actor,
      candidate: candidate,
    ) if grant_token.blank?

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

  def commit_settings_telephone_registration!(surface:, actor:, candidate:)
    config = settings_telephone_registration_config(surface)
    config.fetch(:record_class).transaction do
      locked = config.fetch(:record_class).lock.find(candidate.id)
      raise IdentityTelephoneCeremony::Error,
            "telephone candidate owner changed" unless locked.public_send(config.fetch(:owner_key)) == actor.id
      raise IdentityTelephoneCeremony::Error,
            "telephone candidate is already verified" unless locked.public_send(config.fetch(:status_key)) ==
              config.fetch(:unverified_status)

      locked.update!(config.fetch(:status_key) => config.fetch(:verified_status))
      record_settings_telephone_registration_audit!(config, actor, locked)
      locked
    end
  end

  def settings_telephone_registration_config(surface)
    {
      "app" => {
        record_class: ClientTelephone,
        owner_key: :user_id,
        status_key: :user_telephone_status_id,
        unverified_status: ClientTelephoneStatus::UNVERIFIED,
        verified_status: ClientTelephoneStatus::VERIFIED,
        audit_event_id: ClientChronicleEvent::TELEPHONE_REGISTERED,
      },
      "com" => {
        record_class: VisitorTelephone,
        owner_key: :visitor_id,
        status_key: :visitor_telephone_status_id,
        unverified_status: VisitorTelephoneStatus::UNVERIFIED,
        verified_status: VisitorTelephoneStatus::VERIFIED,
      },
      "org" => {
        record_class: OperatorTelephone,
        owner_key: :staff_id,
        status_key: :staff_telephone_status_id,
        unverified_status: OperatorTelephoneStatus::UNVERIFIED,
        verified_status: OperatorTelephoneStatus::VERIFIED,
      },
    }.fetch(surface.to_s) { raise IdentityTelephoneCeremony::Error, "surface is invalid" }
  end

  def record_settings_telephone_registration_audit!(config, actor, telephone)
    return if config[:audit_event_id].blank?

    IdentityAudit.record!(
      actor: actor,
      event_id: config.fetch(:audit_event_id),
      action: "telephone.register",
      subject: telephone,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
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
