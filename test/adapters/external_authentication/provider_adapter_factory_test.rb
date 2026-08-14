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

  # Entra ID is built by this factory like every other provider; see
  # test/adapters/external_authentication/entra_provider_adapter_test.rb.
  test "builds the Entra adapter" do
    adapter = ExternalAuthentication::ProviderAdapterFactory.build(
      provider: "entra",
      audience: "22222222-3333-4444-5555-666666666666",
    )

    assert_instance_of ExternalAuthentication::EntraProviderAdapter, adapter
  end

  test "requires an audience for the Entra provider" do
    error =
      assert_raises(ArgumentError) do
        ExternalAuthentication::ProviderAdapterFactory.build(provider: "entra")
      end

    assert_equal "audience is required", error.message
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
