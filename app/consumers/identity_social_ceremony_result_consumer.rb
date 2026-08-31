# typed: false
# frozen_string_literal: true

class IdentitySocialCeremonyResultConsumer
  Consumption = Data.define(:transaction, :result)

  def initialize(transaction:, now: Time.current)
    @transaction = transaction
    @now = now
  end

  def call(token)
    result = IdentitySocialCeremonyResult.decode(
      token,
      issuer_id: IdentitySocialCeremonyContract.sign_issuer_id(transaction.surface), now: now,
    )
    validate_result_binding!(result)
    consumed = transaction.consume_result!(
      result_jti: result["result_jti"],
      provider_subject_ref: result["provider_subject_ref"],
      provider_subject_digest: result["provider_subject_digest"],
      consumed_at: now,
    )
    Consumption.new(transaction: consumed, result: result)
  end

  private

  attr_reader :transaction, :now

  def validate_result_binding!(result)
    raise IdentitySocialCeremonyContract::Error, "transaction is expired" if transaction.expired?(now: now)
    raise IdentitySocialCeremonyContract::Error, "transaction is already consumed" if transaction.consumed?
    raise IdentitySocialCeremonyContract::Error,
          "result surface does not match transaction" unless result["surface"].to_s == transaction.surface
    raise IdentitySocialCeremonyContract::Error,
          "result actor does not match transaction" unless result["actor_ref"].to_s == transaction.actor_ref
    raise IdentitySocialCeremonyContract::Error,
          "result session does not match transaction" unless result["session_ref"].to_s == transaction.session_ref
    raise IdentitySocialCeremonyContract::Error,
          "result operation does not match transaction" unless result["operation"].to_s == transaction.operation
    raise IdentitySocialCeremonyContract::Error,
          "result provider does not match transaction" unless result["provider"].to_s == transaction.provider
    raise IdentitySocialCeremonyContract::Error,
          "result transaction does not match transaction" unless result["transaction_id"].to_s ==
            transaction.transaction_id
    raise IdentitySocialCeremonyContract::Error,
          "result grant does not match transaction" unless result["grant_jti"].to_s == transaction.grant_jti
  end
end
