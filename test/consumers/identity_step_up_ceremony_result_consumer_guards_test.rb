# typed: false
# frozen_string_literal: true

require "test_helper"

# A step-up result may only clear the transaction that asked for it. A grant
# that demanded a phishing-resistant factor is not satisfied by a result that
# records none, and a transaction that cannot record its own consumption is a
# contract violation rather than something to consume best-effort.
class IdentityStepUpCeremonyResultConsumerGuardsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def consumer_for(transaction)
    IdentityStepUpCeremonyResultConsumer.new(transaction: transaction)
  end

  test "a result with no phishing resistance does not satisfy a transaction that demands it" do
    transaction = Struct.new(
      :surface, :actor_ref, :session_ref, :transaction_id, :grant_jti, :required_scope,
      :allowed_methods_array, :required_aal, :phishing_resistant_required, keyword_init: true,
    ).new(
      surface: "app", actor_ref: "actor", session_ref: "session", transaction_id: "txn",
      grant_jti: "jti", required_scope: "settings_email", allowed_methods_array: ["passkey"],
      required_aal: StepUpRequirement::NO_AAL, phishing_resistant_required: true,
    )
    result = {
      "surface" => "app",
      "actor_ref" => "actor",
      "session_ref" => "session",
      "transaction_id" => "txn",
      "grant_jti" => "jti",
      "scope" => "settings_email",
      "method" => "passkey",
      "aal" => StepUpRequirement::NO_AAL,
    }
    result.define_singleton_method(:phishing_resistant?) { false }

    error =
      assert_raises(IdentityStepUpCeremonyContract::Error) do
        consumer_for(transaction).send(:validate_result!, result)
      end

    assert_match(/phishing resistance is required/, error.message)
  end

  test "a transaction that cannot record its own consumption is refused" do
    transaction = Struct.new(:surface).new("app")

    error =
      assert_raises(IdentityStepUpCeremonyContract::Error) do
        consumer_for(transaction).send(:consume_result!, {})
      end

    assert_match(/durable step-up ceremony transaction is required/, error.message)
  end
end
