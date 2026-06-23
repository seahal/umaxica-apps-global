# typed: false
# frozen_string_literal: true

module SignSecretCredentialCeremonyDelegation
  extend ActiveSupport::Concern

  private

  def start_secret_credential_ceremony!(_surface:, _actor:, _session_ref:, _operation: "enrollment")
    secret_credential_ceremony_grant_token
  end

  def accept_secret_credential_ceremony_grant!(surface:)
    token = params[:secret_credential_ceremony_grant].to_s
    return false if token.blank?

    grant = IdentitySecretCredentialCeremonyGrant.decode(
      token,
      issuer_id: IdentitySecretCredentialCeremonyContract.acme_issuer_id(surface),
    )
    session[secret_credential_ceremony_session_key] = {
      "grant" => token,
      "transaction_id" => grant["transaction_id"],
    }
    true
  rescue IdentitySecretCredentialCeremonyContract::Error
    false
  end

  def finish_secret_credential_ceremony!(surface:, actor:, session_ref:, record_class:, name:, enabled:,
                                         raw_secret_credential:, operation: "enrollment")
    grant_token = secret_credential_ceremony_grant_token
    if grant_token.blank?
      return create_settings_secret_credential!(
        surface: surface,
        actor: actor,
        record_class: record_class,
        name: name,
        enabled: enabled,
        raw_secret_credential: raw_secret_credential,
      )
    end

    grant = IdentitySecretCredentialCeremonyGrant.decode(
      grant_token,
      issuer_id: IdentitySecretCredentialCeremonyContract.acme_issuer_id(surface),
    )
    raw_secret_credential = raw_secret_credential.presence || record_class.generate_raw_secret_credential
    candidate_record = record_class.new(name: name.to_s)
    candidate_record.password = raw_secret_credential.to_s
    candidate = IdentitySecretCredentialCeremonyCandidateStore.store!(
      surface: surface,
      actor_ref: actor.public_id,
      session_ref: session_ref,
      transaction_id: grant["transaction_id"],
      operation: operation,
      password_digest: candidate_record.password_digest,
      name: name,
      enabled: enabled,
      expires_at: Time.zone.at(grant["exp"].to_i),
    )
    result_token = IdentitySecretCredentialCeremonyResultIssuer.issue!(
      grant_token: grant_token,
      candidate: candidate,
      surface: surface,
      actor_ref: actor.public_id,
      session_ref: session_ref,
      operation: operation,
      challenge_id: candidate.ref,
    )
    IdentitySecretCredentialCeremonyFinalCommitter.call!(
      result_token: result_token,
      actor: actor,
      session_ref: session_ref,
      surface: surface,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
    )
  end

  def create_settings_secret_credential!(surface:, actor:, record_class:, name:, enabled:, raw_secret_credential:)
    params = { name: name, enabled: enabled }
    case surface.to_s
    when "app"
      ClientSecretCredentialsCreate.call(
        actor: actor,
        user: actor,
        params: params,
        raw_secret_credential: raw_secret_credential,
      )
    when "com"
      VisitorSecretCredentialsCreate.call(
        actor: actor,
        visitor: actor,
        params: params,
        raw_secret_credential: raw_secret_credential,
      )
    when "org"
      OperatorSecretCredentialsCreate.call(
        actor: actor,
        staff: actor,
        params: params,
        raw_secret_credential: raw_secret_credential,
      )
    else
      raise IdentitySecretCredentialCeremonyContract::Error, "surface is invalid"
    end
  end

  def secret_credential_ceremony_grant_token
    data = session[secret_credential_ceremony_session_key]
    return data["grant"] if data.respond_to?(:[]) && data["grant"].present?

    nil
  end

  def reset_secret_credential_ceremony_session!
    session.delete(secret_credential_ceremony_session_key)
  end

  def secret_credential_ceremony_session_key
    :secret_credential_ceremony
  end
end
