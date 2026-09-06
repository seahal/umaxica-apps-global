# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationResultTest < ActiveSupport::TestCase
  test "unlink result exposes each supported status" do
    unlinked = ExternalAuthentication::UnlinkResult.new(status: :unlinked, provider: "google")
    already_unlinked = ExternalAuthentication::UnlinkResult.new(status: :already_unlinked, provider: "google")

    assert_predicate unlinked, :unlinked?
    assert_not_predicate unlinked, :already_unlinked?
    assert_not_predicate already_unlinked, :unlinked?
    assert_predicate already_unlinked, :already_unlinked?
  end

  test "unlink result rejects unsupported status and provider" do
    assert_raises(ArgumentError) do
      ExternalAuthentication::UnlinkResult.new(status: :created, provider: "google")
    end
    assert_raises(ArgumentError) do
      ExternalAuthentication::UnlinkResult.new(status: :unlinked, provider: "unknown")
    end
  end

  test "signup result exposes created status and validates required values" do
    user = Object.new
    identity = Object.new
    result = ExternalAuthentication::SignupResult.new(status: :created, user: user, identity: identity)

    assert_predicate result, :created?
    assert_raises(ArgumentError) do
      ExternalAuthentication::SignupResult.new(status: :pending, user: user, identity: identity)
    end
    assert_raises(ArgumentError) do
      ExternalAuthentication::SignupResult.new(status: :created, user: nil, identity: identity)
    end
  end
end
