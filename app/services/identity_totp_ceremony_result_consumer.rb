# typed: false
# frozen_string_literal: true

class IdentityTotpCeremonyResultConsumer
  Consumption = Data.define(:transaction, :result)

  def initialize(transaction:, now: Time.current)
    @transaction = transaction
    @now = now
  end

  def call(token)
    result = IdentityTotpCeremonyResult.decode(token, issuer_id: IdentityTotpCeremonyContract.sign_issuer_id(transaction.surface), now: now)
    validate_result_binding!(result)
    consumed = transaction.consume_result!(result_jti: result["result_jti"], consumed_at: now)
    Consumption.new(transaction: consumed, result: result)
  end

  private

  attr_reader :transaction, :now

  def validate_result_binding!(result)
    raise IdentityTotpCeremonyContract::Error, "transaction is expired" if transaction.expired?(now: now)
    raise IdentityTotpCeremonyContract::Error, "transaction is already consumed" if transaction.consumed?
    raise IdentityTotpCeremonyContract::Error, "result surface does not match transaction" unless result["surface"].to_s == transaction.surface
    raise IdentityTotpCeremonyContract::Error, "result actor does not match transaction" unless result["actor_ref"].to_s == transaction.actor_ref
    raise IdentityTotpCeremonyContract::Error,
          "result session does not match transaction" unless result["session_ref"].to_s == transaction.session_ref
    raise IdentityTotpCeremonyContract::Error,
          "result operation does not match transaction" unless result["operation"].to_s == transaction.operation
    raise IdentityTotpCeremonyContract::Error, "result transaction does not match transaction" unless result["transaction_id"].to_s ==
      transaction.transaction_id
    raise IdentityTotpCeremonyContract::Error, "result grant does not match transaction" unless result["grant_jti"].to_s == transaction.grant_jti
  end
end
