# typed: false
# frozen_string_literal: true

module Sign
  module PasskeyCeremonyDelegation
    extend ActiveSupport::Concern

    private

    def start_passkey_ceremony!(surface:, actor:, session_ref:, operation: "registration")
      return if passkey_ceremony_grant_token.present?

      issuance = Identity::PasskeyCeremony::GrantIssuer.issue!(
        surface: surface,
        actor_ref: actor.public_id,
        session_ref: session_ref,
        operation: operation,
      )
      session[passkey_ceremony_session_key] = {
        "grant" => issuance.grant,
        "transaction_id" => issuance.transaction.transaction_id,
      }
      issuance
    end

    def accept_passkey_ceremony_grant!(surface:)
      token = params[:passkey_ceremony_grant].to_s
      return true if token.blank?

      grant = Identity::PasskeyCeremony::Grant.decode(
        token,
        issuer_id: Identity::PasskeyCeremony::Contract.acme_issuer_id(surface),
      )
      session[passkey_ceremony_session_key] = {
        "grant" => token,
        "transaction_id" => grant["transaction_id"],
      }
      true
    rescue Identity::PasskeyCeremony::Error
      false
    end

    def finish_passkey_ceremony!(surface:, actor:, session_ref:, candidate:, challenge_id:, operation: "registration")
      grant_token = passkey_ceremony_grant_token
      if grant_token.blank?
        grant_token = start_passkey_ceremony!(
          surface: surface,
          actor: actor,
          session_ref: session_ref,
          operation: operation,
        ).grant
      end

      result_token = Identity::PasskeyCeremony::ResultIssuer.issue!(
        grant_token: grant_token,
        candidate: candidate,
        surface: surface,
        actor_ref: actor.public_id,
        session_ref: session_ref,
        operation: operation,
        challenge_id: challenge_id,
      )
      Identity::PasskeyCeremony::FinalCommitter.call!(
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
end
