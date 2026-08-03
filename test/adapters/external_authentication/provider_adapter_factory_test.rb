# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationProviderAdapterFactoryTest < ActiveSupport::TestCase
  test "builds the Apple adapter from the fixed registry" do
    adapter = ExternalAuthentication::ProviderAdapterFactory.build(
      provider: "apple",
      audience: "configured-apple-client-id",
    )

    assert_instance_of ExternalAuthentication::AppleProviderAdapter, adapter
  end

  test "builds the Google adapter from the fixed registry" do
    adapter = ExternalAuthentication::ProviderAdapterFactory.build(
      provider: "google",
      audience: "configured-google-client-id",
    )

    assert_instance_of ExternalAuthentication::GoogleProviderAdapter, adapter
  end

  # Entra ID is not built by this factory; see
  # adr/org-entra-omniauth-strategy-migration.md and
  # test/lib/omniauth/strategies/umaxica_entra_test.rb.
  test "rejects the Entra provider (no longer routed through this factory)" do
    error =
      assert_raises(ArgumentError) do
        ExternalAuthentication::ProviderAdapterFactory.build(provider: "entra")
      end

    assert_equal "adapter is unsupported", error.message
  end

  test "rejects unknown providers without dynamic class lookup" do
    error =
      assert_raises(ArgumentError) do
        ExternalAuthentication::ProviderAdapterFactory.build(
          provider: "ExternalAuthentication::AppleProviderAdapter",
          audience: "configured-client-id",
        )
      end

    assert_equal "provider is unsupported", error.message
  end
end
