# typed: false
# frozen_string_literal: true

module Sign
  module SecretCredentialCeremonyDelegation
    extend ActiveSupport::Concern

    private

    def start_secret_credential_ceremony!(surface:, actor:, session_ref:, operation: "enrollment")
      return if secret_credential_ceremony_grant_token.present?

      issuance = Identity::SecretCredentialCeremony::GrantIssuer.issue!(
        surface: surface,
        actor_ref: actor.public_id,
        session_ref: session_ref,
        operation: operation,
      )
      session[secret_credential_ceremony_session_key] = {
        "grant" => issuance.grant,
        "transaction_id" => issuance.transaction.transaction_id,
      }
      issuance
    end

    def accept_secret_credential_ceremony_grant!(surface:)
      token = params[:secret_credential_ceremony_grant].to_s
      return true if token.blank?

      grant = Identity::SecretCredentialCeremony::Grant.decode(
        token,
        issuer_id: Identity::SecretCredentialCeremony::Contract.acme_issuer_id(surface),
      )
      session[secret_credential_ceremony_session_key] = {
        "grant" => token,
        "transaction_id" => grant["transaction_id"],
      }
      true
    rescue Identity::SecretCredentialCeremony::Error
      false
    end

    def finish_secret_credential_ceremony!(surface:, actor:, session_ref:, record_class:, name:, enabled:,
                                           raw_secret_credential:, operation: "enrollment")
      grant_token = secret_credential_ceremony_grant_token
      if grant_token.blank?
        grant_token = start_secret_credential_ceremony!(
          surface: surface,
          actor: actor,
          session_ref: session_ref,
          operation: operation,
        ).grant
      end

      grant = Identity::SecretCredentialCeremony::Grant.decode(
        grant_token,
        issuer_id: Identity::SecretCredentialCeremony::Contract.acme_issuer_id(surface),
      )
      raw_secret_credential = raw_secret_credential.presence || record_class.generate_raw_secret_credential
      candidate_record = record_class.new(name: name.to_s)
      candidate_record.password = raw_secret_credential.to_s
      candidate = Identity::SecretCredentialCeremony::CandidateStore.store!(
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
      result_token = Identity::SecretCredentialCeremony::ResultIssuer.issue!(
        grant_token: grant_token,
        candidate: candidate,
        surface: surface,
        actor_ref: actor.public_id,
        session_ref: session_ref,
        operation: operation,
        challenge_id: candidate.ref,
      )
      Identity::SecretCredentialCeremony::FinalCommitter.call!(
        result_token: result_token,
        actor: actor,
        session_ref: session_ref,
        surface: surface,
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
      )
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
end
