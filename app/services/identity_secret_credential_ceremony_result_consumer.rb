# typed: false
# frozen_string_literal: true

class IdentitySecretCredentialCeremonyResultConsumer
  Consumption = Data.define(:transaction, :result)

  def initialize(transaction:, now: Time.current)
    @transaction = transaction
    @now = now
  end

  def call(token)
    result = IdentitySecretCredentialCeremonyResult.decode(token, issuer_id: IdentitySecretCredentialCeremonyContract.sign_issuer_id(transaction.surface), now: now)
    validate_result_binding!(result)
    consumed = transaction.consume_result!(result_jti: result["result_jti"], consumed_at: now)
    Consumption.new(transaction: consumed, result: result)
  end

  private

  attr_reader :transaction, :now

  def validate_result_binding!(result)
    raise IdentitySecretCredentialCeremonyContract::Error, "transaction is expired" if transaction.expired?(now: now)
    raise IdentitySecretCredentialCeremonyContract::Error, "transaction is already consumed" if transaction.consumed?
    raise IdentitySecretCredentialCeremonyContract::Error, "result surface does not match transaction" unless result["surface"].to_s == transaction.surface
    raise IdentitySecretCredentialCeremonyContract::Error, "result actor does not match transaction" unless result["actor_ref"].to_s == transaction.actor_ref
    raise IdentitySecretCredentialCeremonyContract::Error,
          "result session does not match transaction" unless result["session_ref"].to_s == transaction.session_ref
    raise IdentitySecretCredentialCeremonyContract::Error,
          "result operation does not match transaction" unless result["operation"].to_s == transaction.operation
    raise IdentitySecretCredentialCeremonyContract::Error, "result transaction does not match transaction" unless result["transaction_id"].to_s ==
      transaction.transaction_id
    raise IdentitySecretCredentialCeremonyContract::Error, "result grant does not match transaction" unless result["grant_jti"].to_s == transaction.grant_jti
  end
end
