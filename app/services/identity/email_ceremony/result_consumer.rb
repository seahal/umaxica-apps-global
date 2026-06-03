# typed: false
# frozen_string_literal: true

module Identity
  module EmailCeremony
    class ResultConsumer
      Consumption = Data.define(:transaction, :result)

      def initialize(transaction:, now: Time.current)
        @transaction = transaction
        @now = now
      end

      def call(token)
        result = Result.decode(token, issuer_id: Contract.sign_issuer_id(transaction.surface), now: now)
        validate_result_binding!(result)
        consumed = transaction.consume_result!(result_jti: result["result_jti"], consumed_at: now)
        Consumption.new(transaction: consumed, result: result)
      end

      private

      attr_reader :transaction, :now

      def validate_result_binding!(result)
        raise Error, "transaction is expired" if transaction.expired?(now: now)
        raise Error, "transaction is already consumed" if transaction.consumed?
        raise Error, "result surface does not match transaction" unless result["surface"].to_s == transaction.surface
        raise Error, "result actor does not match transaction" unless result["actor_ref"].to_s == transaction.actor_ref
        raise Error,
              "result session does not match transaction" unless result["session_ref"].to_s == transaction.session_ref
        raise Error,
              "result operation does not match transaction" unless result["operation"].to_s == transaction.operation
        raise Error, "result transaction does not match transaction" unless result["transaction_id"].to_s ==
          transaction.transaction_id
        raise Error, "result grant does not match transaction" unless result["grant_jti"].to_s == transaction.grant_jti
      end
    end
  end
end
