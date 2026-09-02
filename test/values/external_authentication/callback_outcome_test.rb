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

  test "authenticated outcome requires a user, identity, and existing-account flag" do
    user = Object.new
    identity = Object.new
    outcome = ExternalAuthentication::CallbackOutcome.new(
      status: :authenticated,
      user: user,
      identity: identity,
      existing_account: true,
    )

    assert_predicate outcome, :authenticated?
    assert_raises(ArgumentError) do
      ExternalAuthentication::CallbackOutcome.new(
        status: :authenticated,
        user: nil,
        identity: identity,
        existing_account: true,
      )
    end
    assert_raises(ArgumentError) do
      ExternalAuthentication::CallbackOutcome.new(
        status: :authenticated,
        user: user,
        identity: identity,
        existing_account: false,
      )
    end
  end

  test "link completed outcome requires user and identity and no account classification" do
    user = Object.new
    identity = Object.new
    outcome = ExternalAuthentication::CallbackOutcome.new(
      status: :link_completed,
      user: user,
      identity: identity,
      existing_account: nil,
    )

    assert_predicate outcome, :link_completed?
    assert_raises(ArgumentError) do
      ExternalAuthentication::CallbackOutcome.new(
        status: :link_completed,
        user: nil,
        identity: identity,
        existing_account: nil,
      )
    end
    assert_raises(ArgumentError) do
      ExternalAuthentication::CallbackOutcome.new(
        status: :link_completed,
        user: user,
        identity: identity,
        existing_account: true,
      )
    end
  end

  test "rejects an unsupported status" do
    assert_raises(ArgumentError) do
      ExternalAuthentication::CallbackOutcome.new(
        status: :unknown,
        user: nil,
        identity: nil,
        existing_account: false,
      )
    end
  end
end
