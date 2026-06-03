# typed: false
# frozen_string_literal: true

module Identity
  module TotpCeremony
    class FinalCommitter
      Commit = Data.define(:transaction, :result, :totp)

      def self.call!(result_token:, actor:, session_ref:, surface:, ip_address: nil, user_agent: nil, now: Time.current)
        new(
          result_token: result_token,
          actor: actor,
          session_ref: session_ref,
          surface: surface,
          ip_address: ip_address,
          user_agent: user_agent,
          now: now,
        ).call!
      end

      def initialize(result_token:, actor:, session_ref:, surface:, ip_address: nil, user_agent: nil, now: Time.current)
        @result_token = result_token
        @actor = actor
        @session_ref = session_ref.to_s
        @surface = surface.to_s
        @ip_address = ip_address
        @user_agent = user_agent
        @now = now
      end

      def call!
        validate_surface!
        validate_actor_binding!
        validate_transaction_state!
        candidate = fetch_candidate!
        validate_enrollment_policy!
        consumption = ResultConsumer.new(transaction: transaction, now: now).call(result_token)
        totp = commit_totp!(candidate)
        CandidateStore.delete(candidate.ref)
        record_audit!
        Commit.new(transaction: consumption.transaction, result: consumption.result, totp: totp)
      end

      private

      attr_reader :result_token, :actor, :session_ref, :surface, :ip_address, :user_agent, :now

      def validate_surface!
        raise Error, "surface is invalid" unless surface == "app"
      end

      def validate_actor_binding!
        raise Error, "actor is required" if actor.blank?
        raise Error, "session_ref is required" if session_ref.blank?
        raise Error, "result actor does not match current actor" unless result["actor_ref"].to_s == actor.public_id.to_s
        raise Error, "result session does not match current session" unless result["session_ref"].to_s == session_ref
        raise Error, "result surface does not match current surface" unless result["surface"].to_s == surface
      end

      def validate_transaction_state!
        raise Error, "transaction is expired" if transaction.expired?(now: now)
        raise Error, "transaction is already consumed" if transaction.consumed?
      end

      def fetch_candidate!
        candidate = CandidateStore.fetch!(result["credential_candidate_ref"])
        raise Error, "candidate digest does not match result" unless candidate.digest.to_s ==
          result["credential_candidate_digest"].to_s
        raise Error,
              "candidate actor does not match current actor" unless candidate.actor_ref.to_s == actor.public_id.to_s
        raise Error, "candidate session does not match current session" unless candidate.session_ref.to_s == session_ref
        raise Error, "candidate surface does not match current surface" unless candidate.surface.to_s == surface

        candidate
      end

      def validate_enrollment_policy!
        return if actor.client_totp_credentials.count < ClientTotpCredential::MAX_TOTPS_PER_USER

        raise Error, "TOTP credential limit is reached"
      end

      def commit_totp!(candidate)
        ClientTotpCredential.transaction do
          actor.client_totp_credentials.create!(
            private_key: candidate.private_key,
            last_otp_at: candidate.last_otp_at,
            title: candidate.title,
            user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
          )
        end
      end

      def record_audit!
        Identity::Audit.record!(
          actor: actor,
          event_id: ClientChronicleEvent::TOTP_ENABLED,
          action: "totp.enable",
          ip_address: ip_address,
          user_agent: user_agent,
        )
      end

      def result
        @result ||= Result.decode(result_token, issuer_id: Contract.sign_issuer_id(surface), now: now)
      end

      def transaction
        @transaction ||= ReplayStore.for(surface).find_transaction!(result["transaction_id"])
      end
    end
  end
end
