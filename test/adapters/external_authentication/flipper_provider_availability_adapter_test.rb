# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationFlipperProviderAvailabilityAdapterTest < ActiveSupport::TestCase
  # Stands in for Flipper so each test states its own flag values.
  class StubFlipper
    def initialize(features)
      @features = features
    end

    def enabled?(feature)
      @features.fetch(feature, false)
    end
  end

  OBSERVED_AT = Time.zone.local(2026, 7, 24, 12, 0, 0)

  test "maps an enabled feature to enabled for a new Apple ceremony" do
    decision = adapter(social_ceremony_apple: true, social_ceremony_google: false)
      .start_decision(provider: "apple", operation: "login", context: {})

    assert_equal :enabled, decision.state
    assert_equal "flipper", decision.source
    assert_equal "configured_enabled", decision.reason_code
    assert_equal OBSERVED_AT, decision.observed_at
  end

  test "maps a disabled feature to disabled for a new Google ceremony" do
    decision = adapter(social_ceremony_apple: true, social_ceremony_google: false)
      .start_decision(provider: "google", operation: "signup", context: {})

    assert_equal :disabled, decision.state
    assert_equal "configured_disabled", decision.reason_code
  end

  test "allows an issued callback to drain when new ceremonies are disabled" do
    decision = adapter(social_ceremony_apple: false).callback_decision(
      provider: "apple",
      ceremony: Struct.new(:public_id).new("ceremony-public-id"),
      context: {},
    )

    assert_equal :draining, decision.state
    assert_equal "issued_before_disable", decision.reason_code
  end

  test "controls Entra independently from Apple and Google" do
    subject = adapter(social_ceremony_apple: true, social_ceremony_google: true, social_ceremony_entra: false)

    assert_equal :disabled, subject.start_decision(provider: "entra", operation: "login", context: {}).state
    assert_equal :enabled, subject.start_decision(provider: "apple", operation: "login", context: {}).state
  end

  test "fails closed when the feature was never created in the flag store" do
    decision = adapter.start_decision(provider: "google", operation: "login", context: {})

    assert_equal :disabled, decision.state
  end

  test "rejects providers outside the fixed registry" do
    error =
      assert_raises(ArgumentError) do
        adapter(social_ceremony_apple: true).start_decision(provider: "saml", operation: "login", context: {})
      end

    assert_equal "provider is unsupported", error.message
  end

  test "rejects operations outside the social ceremony contract" do
    error =
      assert_raises(ArgumentError) do
        adapter(social_ceremony_apple: true).start_decision(provider: "apple", operation: "unlink", context: {})
      end

    assert_equal "operation is unsupported", error.message
  end

  test "requires an issued ceremony for callback decisions" do
    error =
      assert_raises(ArgumentError) do
        adapter(social_ceremony_apple: true).callback_decision(provider: "apple", ceremony: nil, context: {})
      end

    assert_equal "ceremony is required", error.message
  end

  test "requires a context" do
    error =
      assert_raises(ArgumentError) do
        adapter(social_ceremony_apple: true).start_decision(provider: "apple", operation: "login", context: nil)
      end

    assert_equal "context is required", error.message
  end

  private

  def adapter(**features)
    ExternalAuthentication::FlipperProviderAvailabilityAdapter.new(
      flipper: StubFlipper.new(features),
      clock: -> { OBSERVED_AT },
    )
  end
end
