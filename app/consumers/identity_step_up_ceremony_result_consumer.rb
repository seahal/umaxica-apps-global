# typed: false
# frozen_string_literal: true

class IdentityStepUpCeremonyResultConsumer
  Consumption = Data.define(:transaction, :result)

  def initialize(transaction:, issuer_id: nil, now: Time.current)
    @transaction = transaction
    @issuer_id = issuer_id || IdentityStepUpCeremonyContract.sign_issuer_id(transaction.surface)
    @now = now
  end

  def call(token)
    result = IdentityStepUpCeremonyResult.decode(token, issuer_id: issuer_id, now: now)

    raise IdentityStepUpCeremonyContract::Error, "transaction is expired" if transaction.expired?(now: now)
    raise IdentityStepUpCeremonyContract::Error, "transaction is already consumed" if transaction.consumed?

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
    require_match!(result, "scope", transaction.required_scope)
    raise IdentityStepUpCeremonyContract::Error,
          "method is not allowed" unless transaction.allowed_methods_array.include?(result["method"].to_s)
    if transaction.required_aal != StepUpRequirement::NO_AAL &&
        aal_rank(result["aal"]) < aal_rank(transaction.required_aal)
      raise IdentityStepUpCeremonyContract::Error, "AAL is insufficient"
    end
    return unless transaction.phishing_resistant_required && !result.phishing_resistant?

    raise IdentityStepUpCeremonyContract::Error, "phishing resistance is required"

  end

  def require_match!(result, key, expected)
    return if result[key].to_s == expected.to_s

    raise IdentityStepUpCeremonyContract::Error, "#{key} does not match transaction"
  end

  def aal_rank(value)
    IdentityStepUpCeremonyContract::AALS.index(value.to_s) || -1
  end

  def consume_result!(result)
    return transaction.consume_result!(
      result_jti: result["result_jti"],
      method: result["method"],
      aal: result["aal"],
      phishing_resistant: result.phishing_resistant?,
      verified_at: Time.zone.at(Integer(result["verified_at"])),
      consumed_at: now,
    ) if transaction.respond_to?(:consume_result!)

    raise IdentityStepUpCeremonyContract::Error, "durable step-up ceremony transaction is required"
  end
end
