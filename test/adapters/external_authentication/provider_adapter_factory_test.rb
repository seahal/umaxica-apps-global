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

  test "builds the Entra adapter from the fixed registry" do
    connection = Data.define(:entra_tenant_id, :entra_client_id, :entra_client_secret).new(
      entra_tenant_id: "11111111-2222-3333-4444-555555555555",
      entra_client_id: "configured-entra-client-id",
      entra_client_secret: "secret",
    )

    adapter = ExternalAuthentication::ProviderAdapterFactory.build(
      provider: "entra",
      connection: connection,
      redirect_uri: "https://auth.example.test/sign/in/entra/callback",
    )

    assert_instance_of ExternalAuthentication::EntraProviderAdapter, adapter
  end

  test "rejects an Entra adapter without per-connection configuration" do
    error =
      assert_raises(ArgumentError) do
        ExternalAuthentication::ProviderAdapterFactory.build(provider: "entra")
      end

    assert_equal "connection is required", error.message
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
