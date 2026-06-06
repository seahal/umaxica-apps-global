# typed: false
# frozen_string_literal: true

class IdentityEmailCeremonyResultConsumer
  Consumption = Data.define(:transaction, :result)

  def initialize(transaction:, now: Time.current)
    @transaction = transaction
    @now = now
  end

  def call(token)
    result = IdentityEmailCeremonyResult.decode(
      token,
      issuer_id: IdentityEmailCeremonyContract.sign_issuer_id(transaction.surface), now: now,
    )
    validate_result_binding!(result)
    consumed = transaction.consume_result!(result_jti: result["result_jti"], consumed_at: now)
    Consumption.new(transaction: consumed, result: result)
  end

  private

  attr_reader :transaction, :now

  def validate_result_binding!(result)
    raise IdentityEmailCeremonyContract::Error, "transaction is expired" if transaction.expired?(now: now)
    raise IdentityEmailCeremonyContract::Error, "transaction is already consumed" if transaction.consumed?
    raise IdentityEmailCeremonyContract::Error,
          "result surface does not match transaction" unless result["surface"].to_s == transaction.surface
    raise IdentityEmailCeremonyContract::Error,
          "result actor does not match transaction" unless result["actor_ref"].to_s == transaction.actor_ref
    raise IdentityEmailCeremonyContract::Error,
          "result session does not match transaction" unless result["session_ref"].to_s == transaction.session_ref
    raise IdentityEmailCeremonyContract::Error,
          "result operation does not match transaction" unless result["operation"].to_s == transaction.operation
    raise IdentityEmailCeremonyContract::Error,
          "result transaction does not match transaction" unless result["transaction_id"].to_s ==
            transaction.transaction_id
    raise IdentityEmailCeremonyContract::Error,
          "result grant does not match transaction" unless result["grant_jti"].to_s == transaction.grant_jti
  end
end
