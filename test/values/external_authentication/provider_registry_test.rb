# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationProviderRegistryTest < ActiveSupport::TestCase
  test "returns the fixed Apple OIDC contract" do
    entry = ExternalAuthentication::ProviderRegistry.fetch("apple")

    assert_equal "apple", entry.provider
    assert_equal :oidc, entry.protocol
    assert_equal "https://appleid.apple.com", entry.issuer
    assert_equal :OMNI_AUTH_APPLE_CLIENT_ID, entry.audience_credential_key
    assert_equal "/social/apple", entry.request_path
    assert_equal "/social/apple/callback", entry.callback_path
    assert_equal :auth_app, entry.callback_origin_key
    assert_equal :apple_oidc, entry.adapter_key
    assert_not_respond_to entry, :enabled
  end

  test "returns online-only Google authorization policies" do
    entry = ExternalAuthentication::ProviderRegistry.fetch("google")

    %i(login signup link).each do |operation|
      policy = entry.authorization_policies.fetch(operation)

      assert_equal "openid", policy.scope
      assert_equal "online", policy.access_type
      assert_equal "select_account", policy.prompt
    end
  end

  test "returns minimal Apple authorization policies" do
    entry = ExternalAuthentication::ProviderRegistry.fetch("apple")

    %i(login signup link).each do |operation|
      policy = entry.authorization_policies.fetch(operation)

      assert_equal "", policy.scope
      assert_nil policy.access_type
      assert_nil policy.prompt
    end
  end

  test "returns the tenant-specific Entra login contract" do
    entry = ExternalAuthentication::ProviderRegistry.fetch("entra")
    policy = entry.authorization_policies.fetch(:login)

    assert_equal :oidc, entry.protocol
    assert_nil entry.issuer
    assert_equal "https://login.microsoftonline.com/%s/v2.0", entry.issuer_template
    assert_equal "/sign/in/entra/authorization", entry.request_path
    assert_equal "/sign/in/entra/callback", entry.callback_path
    assert_equal :auth_staff, entry.callback_origin_key
    assert_equal :entra_oidc, entry.adapter_key
    assert_equal "openid profile", policy.scope
    assert_nil policy.access_type
    assert_nil policy.prompt
    assert_not entry.authorization_policies.key?(:signup)
    assert_not entry.authorization_policies.key?(:link)
  end

  test "rejects providers outside the fixed registry" do
    error =
      assert_raises(ArgumentError) do
        ExternalAuthentication::ProviderRegistry.fetch("saml")
      end

    assert_equal "provider is unsupported", error.message
  end

  test "does not normalize attacker-controlled provider values" do
    assert_raises(ArgumentError) do
      ExternalAuthentication::ProviderRegistry.fetch("APPLE")
    end
    assert_raises(ArgumentError) do
      ExternalAuthentication::ProviderRegistry.fetch(:apple)
    end
  end
end
