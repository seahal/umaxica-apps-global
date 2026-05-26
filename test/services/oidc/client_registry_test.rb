# typed: false
# frozen_string_literal: true

require "test_helper"

class Oidc::ClientRegistryTest < ActiveSupport::TestCase
  def with_oidc_client_secret_credentials(overrides)
    creds = Rails.app.creds
    fetch = ->(key, default: nil) { overrides.fetch(key, default) }

    creds.stub(:option, fetch) do
      yield
    end
  end

  test "find returns client for known client_id" do
    client = Oidc::ClientRegistry.find("core_app")

    assert_not_nil client
    assert_equal "core_app", client.client_id
    assert_equal "umaxica-core-app", client.aud
    assert_equal "client", client.resource_type
    assert_equal "Core App", client.name
    assert_includes client.domains, ENV.fetch("CORE_SERVICE_URL", "jp.www.umaxica.app")
    assert_kind_of Array, client.redirect_uris
    assert client.redirect_uris.any? { |uri| uri.include?("/auth/callback") }
  end

  test "find returns nil for unknown client_id" do
    assert_nil Oidc::ClientRegistry.find("unknown_client")
  end

  test "find! raises for unknown client_id" do
    assert_raises(Oidc::ClientRegistry::ClientNotFound) do
      Oidc::ClientRegistry.find!("unknown_client")
    end
  end

  test "valid_redirect_uri? returns true for registered URI" do
    client = Oidc::ClientRegistry.find("core_app")
    uri = client.redirect_uris.first

    assert Oidc::ClientRegistry.valid_redirect_uri?("core_app", uri)
  end

  test "valid_redirect_uri? returns false for unregistered URI" do
    assert_not Oidc::ClientRegistry.valid_redirect_uri?("core_app", "https://evil.com/callback")
  end

  test "valid_redirect_uri? returns false for unknown client" do
    assert_not Oidc::ClientRegistry.valid_redirect_uri?("unknown", "http://localhost/callback")
  end

  test "all expected clients are registered" do
    expected = %w(
      apex_app apex_org apex_com
      core_app core_org core_com
      docs_app docs_org docs_com
      news_app news_org news_com
      help_app help_org help_com
    )

    expected.each do |client_id|
      client = Oidc::ClientRegistry.find(client_id)

      assert_not_nil client, "VisitorAccount #{client_id} should be registered"
      assert_predicate client.redirect_uris, :present?, "VisitorAccount #{client_id} should have redirect_uris"
      assert_predicate client.aud, :present?, "VisitorAccount #{client_id} should have aud"
    end
  end

  test "org clients have operator resource_type" do
    %w(apex_org core_org docs_org news_org help_org).each do |client_id|
      client = Oidc::ClientRegistry.find(client_id)

      assert_equal "operator", client.resource_type, "#{client_id} should be operator type"
    end
  end

  test "app clients have client resource_type" do
    %w(apex_app core_app docs_app news_app help_app).each do |client_id|
      client = Oidc::ClientRegistry.find(client_id)

      assert_equal "client", client.resource_type, "#{client_id} should be client type"
    end
  end

  test "com clients have visitor resource_type" do
    %w(apex_com core_com docs_com news_com help_com).each do |client_id|
      client = Oidc::ClientRegistry.find(client_id)

      assert_equal "visitor", client.resource_type, "#{client_id} should be visitor type"
    end
  end

  test "authenticate returns false when secrets are not configured" do
    assert_not Oidc::ClientRegistry.authenticate("core_app", "any_secret")
  end

  test "find resolves secret from flat credential key" do
    with_oidc_client_secret_credentials(OIDC_CLIENT_SECRETS_CORE_APP: "core-app-secret") do
      client = Oidc::ClientRegistry.find("core_app")

      assert_equal "core-app-secret", client.client_secret
    end
  end

  test "authenticate uses flat credential key" do
    with_oidc_client_secret_credentials(OIDC_CLIENT_SECRETS_APEX_ORG: "apex-org-secret") do
      assert Oidc::ClientRegistry.authenticate("apex_org", "apex-org-secret")
      assert_not Oidc::ClientRegistry.authenticate("apex_org", "wrong-secret")
    end
  end

  test "authenticate returns false for blank secret" do
    assert_not Oidc::ClientRegistry.authenticate("core_app", "")
    assert_not Oidc::ClientRegistry.authenticate("core_app", nil)
  end

  test "client_ids returns all registered client IDs" do
    ids = Oidc::ClientRegistry.client_ids

    assert_includes ids, "core_app"
    assert_includes ids, "apex_org"
    assert_equal 15, ids.size
  end

  test "core clients are registered to regional redirect hosts" do
    expectations = {
      "core_app" => {
        host: ENV.fetch("CORE_SERVICE_URL", "jp.www.umaxica.app"),
        aud: "umaxica-core-app",
        resource_type: "client",
      },
      "core_com" => {
        host: ENV.fetch("CORE_CORPORATE_URL", "jp.www.umaxica.com"),
        aud: "umaxica-core-com",
        resource_type: "visitor",
      },
      "core_org" => {
        host: ENV.fetch("CORE_STAFF_URL", "jp.www.umaxica.org"),
        aud: "umaxica-core-org",
        resource_type: "operator",
      },
    }

    expectations.each do |client_id, expected|
      client = Oidc::ClientRegistry.find!(client_id)
      redirect_uri = URI.parse(client.redirect_uris.fetch(0))

      assert_equal expected[:host], redirect_uri.host, "#{client_id} redirect host is not regional"
      assert_equal "/auth/callback", redirect_uri.path
      assert_equal expected[:aud], client.aud
      assert_equal expected[:resource_type], client.resource_type
      assert_equal [expected[:host]], client.domains
    end
  end

  test "apex clients are registered to same surface redirect hosts" do
    expectations = {
      "apex_app" => {
        host: ENV.fetch("APEX_SERVICE_URL", "www.app.localhost"),
        aud: "umaxica-apex-app",
        resource_type: "client",
      },
      "apex_com" => {
        host: ENV.fetch("APEX_CORPORATE_URL", "www.com.localhost"),
        aud: "umaxica-apex-com",
        resource_type: "visitor",
      },
      "apex_org" => {
        host: ENV.fetch("APEX_STAFF_URL", "www.org.localhost"),
        aud: "umaxica-apex-org",
        resource_type: "operator",
      },
    }

    expectations.each do |client_id, expected|
      client = Oidc::ClientRegistry.find!(client_id)
      redirect_uri = URI.parse(client.redirect_uris.fetch(0))

      assert_equal expected[:host], redirect_uri.host, "#{client_id} redirect host is cross-surface"
      assert_equal "/auth/callback", redirect_uri.path
      assert_equal expected[:aud], client.aud
      assert_equal expected[:resource_type], client.resource_type
      assert_equal [expected[:host]], client.domains
    end
  end
end
