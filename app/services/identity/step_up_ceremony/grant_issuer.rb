# typed: false
# frozen_string_literal: true

module Identity
  module StepUpCeremony
    class GrantIssuer
      Issuance = Data.define(:transaction, :grant)

      def self.issue!(surface:, actor_ref:, session_ref:, required_scope:, required_aal:, allowed_methods:,
                      resource_ref: nil, return_to: nil, transaction_id: nil, grant_jti: nil, expires_at: nil,
                      now: Time.current)
        transaction =
          ReplayStore.for(surface).create_transaction!(
            surface: surface,
            actor_ref: actor_ref,
            session_ref: session_ref,
            required_scope: required_scope,
            required_aal: required_aal,
            allowed_methods: allowed_methods,
            resource_ref: resource_ref,
            return_to: return_to,
            transaction_id: transaction_id,
            grant_jti: grant_jti,
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
