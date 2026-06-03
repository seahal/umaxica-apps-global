# typed: false
# frozen_string_literal: true

module Identity
  module SocialCeremony
    class ResultIssuer
      def self.issue!(grant_token:, auth_hash:, surface:, actor_ref:, session_ref:, operation:, challenge_id: nil,
                      now: Time.current)
        new(
          grant_token: grant_token,
          auth_hash: auth_hash,
          surface: surface,
          actor_ref: actor_ref,
          session_ref: session_ref,
          operation: operation,
          challenge_id: challenge_id,
          now: now,
        ).issue!
      end

      def initialize(grant_token:, auth_hash:, surface:, actor_ref:, session_ref:, operation:, challenge_id: nil,
                     now: Time.current)
        @grant_token = grant_token
        @auth_hash = auth_hash
        @surface = surface.to_s
        @actor_ref = actor_ref.to_s
        @session_ref = session_ref.to_s
        @operation = operation.to_s
        @challenge_id = challenge_id
        @now = now
      end

      def issue!
        validate_grant!
        Result.issue(result_claims, issuer_id: Contract.sign_issuer_id(surface), now: now)
      end

      private

      attr_reader :grant_token, :auth_hash, :surface, :actor_ref, :session_ref, :operation, :challenge_id, :now

      def validate_grant!
        raise Error, "social ceremony grant is required" if grant_token.blank?
        raise Error, "provider subject is required" if provider_subject.blank?
        raise Error, "grant surface does not match ceremony" unless grant["surface"].to_s == surface
        raise Error, "grant actor does not match ceremony" unless grant["actor_ref"].to_s == actor_ref
        raise Error, "grant session does not match ceremony" unless grant["session_ref"].to_s == session_ref
        raise Error, "grant operation does not match ceremony" unless grant["operation"].to_s == operation
        raise Error, "grant provider does not match ceremony" unless grant["provider"].to_s == provider
        raise Error, "grant jti does not match transaction" unless grant["jti"].to_s == transaction.grant_jti.to_s
        raise Error, "transaction is expired" if transaction.expired?(now: now)
        raise Error, "transaction is already consumed" if transaction.consumed?
      end

      def grant
        @grant ||= Grant.decode(grant_token, issuer_id: Contract.acme_issuer_id(surface), now: now)
      end

      def transaction
        @transaction ||= ReplayStore.for(surface).find_transaction!(grant["transaction_id"])
      end

      def provider
        @provider ||= auth_hash_value(:provider).to_s
      end

      def provider_subject
        @provider_subject ||= SocialAuth::UidExtractor.call(auth_hash: auth_hash).to_s
      end

      def provider_subject_digest
        @provider_subject_digest ||= Contract.provider_subject_digest(provider: provider, subject: provider_subject)
      end

      def candidate
        return unless operation != "link"

        @candidate ||= CandidateStore.store!(
          surface: surface,
          actor_ref: actor_ref,
          session_ref: session_ref,
          transaction_id: transaction.transaction_id,
          operation: operation,
          provider: provider,
          auth_hash: auth_hash,
          expires_at: transaction.expires_at,
        )
      end

      def email_digest
        email = auth_hash.dig("info", "email").presence || auth_hash.dig(:info, :email).presence
        return if email.blank?

        Digest::SHA256.hexdigest(email.to_s.downcase.strip)
      end

      def email_verified
        value = auth_hash.dig("extra", "raw_info", "email_verified")
        value = auth_hash.dig(:extra, :raw_info, :email_verified) if value.nil?
        return if value.nil?

        !!value
      end

      def auth_hash_value(key)
        return auth_hash[key] || auth_hash[key.to_s] if auth_hash.respond_to?(:[])
        return auth_hash.public_send(key) if auth_hash.respond_to?(key)

        nil
      rescue NoMethodError
        nil
      end

      def result_claims
        {
          "surface" => surface,
          "actor_ref" => actor_ref,
          "session_ref" => session_ref,
          "transaction_id" => transaction.transaction_id,
          "grant_jti" => transaction.grant_jti,
          "result_jti" => SecureRandom.uuid,
          "operation" => operation,
          "provider" => provider,
          "provider_subject_ref" => provider_subject_digest,
          "provider_subject_digest" => provider_subject_digest,
          "email_digest" => email_digest,
          "email_verified" => email_verified,
          "candidate_ref" => candidate&.ref,
          "candidate_digest" => candidate&.digest,
          "verified_at" => now.to_i,
          "challenge_id" => challenge_id.presence || transaction.transaction_id,
          "expires_at" => transaction.expires_at.to_i,
        }.compact
      end
    end
  end
end
