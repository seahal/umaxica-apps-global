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
    assert_equal "/social/entra", entry.request_path
    assert_equal "/social/entra/callback", entry.callback_path
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

  test "lists registered providers" do
    assert_equal %w(apple google entra), ExternalAuthentication::ProviderRegistry.providers
  end

  test "rejects tenant lookup for a provider that is not tenant scoped" do
    error = assert_raises(ArgumentError) { ExternalAuthentication::ProviderRegistry.tenant_id("apple") }

    assert_equal "provider is not tenant scoped", error.message
  end

  test "returns entra tenant id and interpolated issuer from credentials" do
    tenant_id = Rails.app.creds.option(:OMNI_AUTH_ENTRA_ORG_TENANT_ID).to_s

    assert_predicate tenant_id, :present?
    assert_equal tenant_id, ExternalAuthentication::ProviderRegistry.tenant_id("entra")
    assert_equal(
      format("https://login.microsoftonline.com/%s/v2.0", tenant_id),
      ExternalAuthentication::ProviderRegistry.issuer_for("entra"),
    )
  end

  test "returns the fixed issuer for a non-tenant provider" do
    assert_equal "https://appleid.apple.com", ExternalAuthentication::ProviderRegistry.issuer_for("apple")
  end

  test "returns the audience credential for apple" do
    audience = Rails.app.creds.option(:OMNI_AUTH_APPLE_CLIENT_ID).to_s

    assert_predicate audience, :present?
    assert_equal audience, ExternalAuthentication::ProviderRegistry.audience("apple")
  end

  test "rejects tenant lookup when the entra tenant credential is blank" do
    Rails.app.creds.stub(
      :option, lambda { |key|
                 (key == :OMNI_AUTH_ENTRA_ORG_TENANT_ID) ? "" : Rails.app.creds.option(key)
               },
    ) do
      error = assert_raises(KeyError) { ExternalAuthentication::ProviderRegistry.tenant_id("entra") }

      assert_match(/OMNI_AUTH_ENTRA_ORG_TENANT_ID/, error.message)
    end
  end

  test "rejects audience lookup when the apple client credential is blank" do
    Rails.app.creds.stub(
      :option, lambda { |key|
                 (key == :OMNI_AUTH_APPLE_CLIENT_ID) ? "" : Rails.app.creds.option(key)
               },
    ) do
      error = assert_raises(KeyError) { ExternalAuthentication::ProviderRegistry.audience("apple") }

      assert_match(/OMNI_AUTH_APPLE_CLIENT_ID/, error.message)
    end
  end
end
