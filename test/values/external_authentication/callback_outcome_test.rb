# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationCallbackOutcomeTest < ActiveSupport::TestCase
  test "signup required outcome is typed and immutable" do
    outcome = ExternalAuthentication::CallbackOutcome.new(
      status: :signup_required,
      user: nil,
      identity: nil,
      existing_account: false,
      entry: "sign_up",
    )

    assert_predicate outcome, :signup_required?
    assert_equal "sign_up", outcome.entry
    assert_predicate outcome, :frozen?
  end

  test "rejects contradictory signup state" do
    assert_raises(ArgumentError) do
      ExternalAuthentication::CallbackOutcome.new(
        status: :signup_required,
        user: Object.new,
        identity: nil,
        existing_account: false,
      )
    end
  end
end
