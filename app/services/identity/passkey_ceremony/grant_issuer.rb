# typed: false
# frozen_string_literal: true

module Identity
  module PasskeyCeremony
    class GrantIssuer
      Issuance = Data.define(:transaction, :grant)

      def self.issue!(surface:, actor_ref:, session_ref:, operation:, credential_candidate_ref: nil,
                      credential_candidate_digest: nil, expires_at: nil, now: Time.current)
        transaction =
          ReplayStore.for(surface).create_transaction!(
            surface: surface,
            actor_ref: actor_ref,
            session_ref: session_ref,
            operation: operation,
            credential_candidate_ref: credential_candidate_ref,
            credential_candidate_digest: credential_candidate_digest,
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
