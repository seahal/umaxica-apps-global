# typed: false
# frozen_string_literal: true

module Identity
  module TelephoneCeremony
    class ResultConsumer
      Consumption = Data.define(:transaction, :result)

      def initialize(transaction:, issuer_id: nil, now: Time.current)
        @transaction = transaction
        @issuer_id = issuer_id || Contract.sign_issuer_id(transaction.surface)
        @now = now
      end

      def call(token)
        result = Result.decode(token, issuer_id: issuer_id, now: now)

        raise Error, "transaction is expired" if transaction.expired?(now: now)
        raise Error, "transaction is already consumed" if transaction.consumed?

        validate_result!(result)
        consumed_transaction = consume_result!(result)

        Consumption.new(transaction: consumed_transaction, result: result)
      end

      private

      attr_reader :transaction, :issuer_id, :now

      def validate_result!(result)
        require_match!(result, "surface", transaction.surface)
        require_match!(result, "actor_ref", transaction.actor_ref)
        require_match!(result, "session_ref", transaction.session_ref)
        require_match!(result, "transaction_id", transaction.transaction_id)
        require_match!(result, "grant_jti", transaction.grant_jti)
        require_match!(result, "operation", transaction.operation)
      end

      def require_match!(result, key, expected)
        return if result[key].to_s == expected.to_s

        raise Error, "#{key} does not match transaction"
      end

      def consume_result!(result)
        return transaction.consume_result!(
          result_jti: result["result_jti"],
          consumed_at: now,
        ) if transaction.respond_to?(:consume_result!)

        raise Error, "durable telephone ceremony transaction is required"
      end
    end
  end
end
