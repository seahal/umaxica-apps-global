# typed: false
# frozen_string_literal: true

class IdentityPasskeyCeremonyResultConsumer
  Consumption = Data.define(:transaction, :result)

  def initialize(transaction:, now: Time.current)
    @transaction = transaction
    @now = now
  end

  def call(token)
    result = IdentityPasskeyCeremonyResult.decode(
      token,
      issuer_id: IdentityPasskeyCeremonyContract.sign_issuer_id(transaction.surface), now: now,
    )
    validate_result_binding!(result)
    consumed = transaction.consume_result!(result_jti: result["result_jti"], consumed_at: now)
    Consumption.new(transaction: consumed, result: result)
  end

  private

  attr_reader :transaction, :now

  def validate_result_binding!(result)
    raise IdentityPasskeyCeremonyContract::Error, "transaction is expired" if transaction.expired?(now: now)
    raise IdentityPasskeyCeremonyContract::Error, "transaction is already consumed" if transaction.consumed?
    raise IdentityPasskeyCeremonyContract::Error,
          "result surface does not match transaction" unless result["surface"].to_s == transaction.surface
    raise IdentityPasskeyCeremonyContract::Error,
          "result actor does not match transaction" unless result["actor_ref"].to_s == transaction.actor_ref
    raise IdentityPasskeyCeremonyContract::Error,
          "result session does not match transaction" unless result["session_ref"].to_s == transaction.session_ref
    raise IdentityPasskeyCeremonyContract::Error,
          "result operation does not match transaction" unless result["operation"].to_s == transaction.operation
    raise IdentityPasskeyCeremonyContract::Error,
          "result transaction does not match transaction" unless result["transaction_id"].to_s ==
            transaction.transaction_id
    raise IdentityPasskeyCeremonyContract::Error,
          "result grant does not match transaction" unless result["grant_jti"].to_s == transaction.grant_jti
  end
end
