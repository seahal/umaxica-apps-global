# typed: false
# frozen_string_literal: true

module Identity
  module EmailCeremony
    class GrantIssuer
      Issuance = Data.define(:transaction, :grant)

      def self.issue!(surface:, actor_ref:, session_ref:, operation:, email_candidate_ref: nil,
                      normalized_email_digest: nil, expires_at: nil, now: Time.current)
        transaction =
          ReplayStore.for(surface).create_transaction!(
            surface: surface,
            actor_ref: actor_ref,
            session_ref: session_ref,
            operation: operation,
            email_candidate_ref: email_candidate_ref,
            normalized_email_digest: normalized_email_digest,
            expires_at: expires_at,
            now: now,
          )
        Issuance.new(transaction: transaction, grant: new(transaction: transaction, now: now).call)
      end

      def initialize(transaction:, issuer_id: nil, now: Time.current)
        @transaction = transaction
        @issuer_id = issuer_id || Contract.acme_issuer_id(transaction.surface)
        @now = now
      end

      def call
        Grant.issue(transaction.grant_claims(now: now), issuer_id: issuer_id, now: now)
      end

      private

      attr_reader :transaction, :issuer_id, :now
    end
  end
end
