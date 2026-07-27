# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationEnvironmentProviderAvailabilityAdapterTest < ActiveSupport::TestCase
  test "maps true to enabled for a new Apple ceremony" do
    observed_at = Time.zone.local(2026, 7, 24, 12, 0, 0)
    adapter = ExternalAuthentication::EnvironmentProviderAvailabilityAdapter.new(
      environment: {
        "APPLE_SOCIAL_CEREMONY_ENABLED" => "true",
        "GOOGLE_SOCIAL_CEREMONY_ENABLED" => "false",
      },
      clock: -> { observed_at },
    )

    decision = adapter.start_decision(provider: "apple", operation: "login", context: {})

    assert_equal :enabled, decision.state
    assert_equal "environment", decision.source
    assert_equal "configured_enabled", decision.reason_code
    assert_equal observed_at, decision.observed_at
  end

  test "maps false to disabled for a new Google ceremony" do
    adapter = ExternalAuthentication::EnvironmentProviderAvailabilityAdapter.new(
      environment: {
        "APPLE_SOCIAL_CEREMONY_ENABLED" => "true",
        "GOOGLE_SOCIAL_CEREMONY_ENABLED" => "false",
      },
      clock: -> { Time.zone.local(2026, 7, 24, 12, 0, 0) },
    )

    decision = adapter.start_decision(provider: "google", operation: "signup", context: {})

    assert_equal :disabled, decision.state
    assert_equal "configured_disabled", decision.reason_code
  end

  test "allows an issued callback to drain when new ceremonies are disabled" do
    adapter = ExternalAuthentication::EnvironmentProviderAvailabilityAdapter.new(
      environment: {
        "APPLE_SOCIAL_CEREMONY_ENABLED" => "false",
        "GOOGLE_SOCIAL_CEREMONY_ENABLED" => "true",
      },
      clock: -> { Time.zone.local(2026, 7, 24, 12, 0, 0) },
    )

    decision = adapter.callback_decision(
      provider: "apple",
      ceremony: Struct.new(:public_id).new("ceremony-public-id"),
      context: {},
    )

    assert_equal :draining, decision.state
    assert_equal "issued_before_disable", decision.reason_code
  end

  test "controls Entra independently from Apple and Google" do
    adapter = ExternalAuthentication::EnvironmentProviderAvailabilityAdapter.new(
      environment: {
        "APPLE_SOCIAL_CEREMONY_ENABLED" => "true",
        "GOOGLE_SOCIAL_CEREMONY_ENABLED" => "true",
        "ENTRA_SOCIAL_CEREMONY_ENABLED" => "false",
      },
      clock: -> { Time.zone.local(2026, 7, 24, 12, 0, 0) },
    )

    entra = adapter.start_decision(provider: "entra", operation: "login", context: {})
    apple = adapter.start_decision(provider: "apple", operation: "login", context: {})

    assert_equal :disabled, entra.state
    assert_equal :enabled, apple.state
  end

  test "fails closed when the requested provider setting is missing" do
    assert_raises(KeyError) do
      adapter = ExternalAuthentication::EnvironmentProviderAvailabilityAdapter.new(
        environment: {
          "APPLE_SOCIAL_CEREMONY_ENABLED" => "true",
        },
        clock: -> { Time.zone.local(2026, 7, 24, 12, 0, 0) },
      )
      adapter.start_decision(provider: "google", operation: "login", context: {})
    end
  end

  test "fails construction when a provider setting is not a strict boolean" do
    error =
      assert_raises(ExternalAuthentication::EnvironmentProviderAvailabilityAdapter::ConfigurationError) do
        adapter = ExternalAuthentication::EnvironmentProviderAvailabilityAdapter.new(
          environment: {
            "APPLE_SOCIAL_CEREMONY_ENABLED" => "yes",
            "GOOGLE_SOCIAL_CEREMONY_ENABLED" => "true",
          },
          clock: -> { Time.zone.local(2026, 7, 24, 12, 0, 0) },
        )
        adapter.start_decision(provider: "apple", operation: "login", context: {})
      end

    assert_equal "APPLE_SOCIAL_CEREMONY_ENABLED must be true or false", error.message
  end

  test "rejects providers outside the fixed registry" do
    adapter = ExternalAuthentication::EnvironmentProviderAvailabilityAdapter.new(
      environment: {
        "APPLE_SOCIAL_CEREMONY_ENABLED" => "true",
        "GOOGLE_SOCIAL_CEREMONY_ENABLED" => "true",
      },
      clock: -> { Time.zone.local(2026, 7, 24, 12, 0, 0) },
    )

    error =
      assert_raises(ArgumentError) do
        adapter.start_decision(provider: "saml", operation: "login", context: {})
      end

    assert_equal "provider is unsupported", error.message
  end

  test "rejects operations outside the social ceremony contract" do
    adapter = ExternalAuthentication::EnvironmentProviderAvailabilityAdapter.new(
      environment: {
        "APPLE_SOCIAL_CEREMONY_ENABLED" => "true",
        "GOOGLE_SOCIAL_CEREMONY_ENABLED" => "true",
      },
      clock: -> { Time.zone.local(2026, 7, 24, 12, 0, 0) },
    )

    error =
      assert_raises(ArgumentError) do
        adapter.start_decision(provider: "apple", operation: "unlink", context: {})
      end

    assert_equal "operation is unsupported", error.message
  end

  test "requires an issued ceremony for callback decisions" do
    adapter = ExternalAuthentication::EnvironmentProviderAvailabilityAdapter.new(
      environment: {
        "APPLE_SOCIAL_CEREMONY_ENABLED" => "true",
        "GOOGLE_SOCIAL_CEREMONY_ENABLED" => "true",
      },
      clock: -> { Time.zone.local(2026, 7, 24, 12, 0, 0) },
    )

    error =
      assert_raises(ArgumentError) do
        adapter.callback_decision(provider: "apple", ceremony: nil, context: {})
      end

    assert_equal "ceremony is required", error.message
  end
end
