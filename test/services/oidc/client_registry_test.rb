# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcClientRegistryTest < ActiveSupport::TestCase
  def with_oidc_client_secret_credentials(overrides)
    creds = Rails.app.creds
    fetch = ->(key, default: nil) { overrides.fetch(key, default) }

    creds.stub(:option, fetch) do
      yield
    end
  end

  test "find returns client for known client_id" do
    client = OidcClientRegistry.find("core_app")

    assert_not_nil client
    assert_equal "core_app", client.client_id
    assert_equal "umaxica-core-app", client.aud
    assert_equal "client", client.resource_type
    assert_equal "Core App", client.name
    assert_includes client.domains, ENV.fetch("CORE_SERVICE_URL", "www.jp.umaxica.app")
    assert_kind_of Array, client.redirect_uris
    assert client.redirect_uris.any? { |uri| uri.include?("/auth/callback") }
  end

  test "find returns nil for unknown client_id" do
    assert_nil OidcClientRegistry.find("unknown_client")
  end

  test "find! raises for unknown client_id" do
    assert_raises(OidcClientRegistry::ClientNotFound) do
      OidcClientRegistry.find!("unknown_client")
    end
  end

  test "valid_redirect_uri? returns true for registered URI" do
    client = OidcClientRegistry.find("core_app")
    uri = client.redirect_uris.first

    assert OidcClientRegistry.valid_redirect_uri?("core_app", uri)
  end

  test "valid_redirect_uri? returns false for unregistered URI" do
    assert_not OidcClientRegistry.valid_redirect_uri?("core_app", "https://evil.com/callback")
  end

  test "valid_redirect_uri? returns false for unknown client" do
    assert_not OidcClientRegistry.valid_redirect_uri?("unknown", "http://localhost/callback")
  end

  test "all expected clients are registered" do
    expected = %w(
      sign_app sign_org sign_com
      acme_app acme_org acme_com
      core_app core_org core_com
      docs_app docs_org docs_com
      news_app news_org news_com
      help_app help_org help_com
    )

    expected.each do |client_id|
      client = OidcClientRegistry.find(client_id)

      assert_not_nil client, "VisitorAccount #{client_id} should be registered"
      assert_predicate client.redirect_uris, :present?, "VisitorAccount #{client_id} should have redirect_uris"
      assert_predicate client.aud, :present?, "VisitorAccount #{client_id} should have aud"
    end
  end

  test "org clients have operator resource_type" do
    %w(sign_org acme_org core_org docs_org news_org help_org).each do |client_id|
      client = OidcClientRegistry.find(client_id)

      assert_equal "operator", client.resource_type, "#{client_id} should be operator type"
    end
  end

  test "app clients have client resource_type" do
    %w(sign_app acme_app core_app docs_app news_app help_app).each do |client_id|
      client = OidcClientRegistry.find(client_id)

      assert_equal "client", client.resource_type, "#{client_id} should be client type"
    end
  end

  test "com clients have visitor resource_type" do
    %w(sign_com acme_com core_com docs_com news_com help_com).each do |client_id|
      client = OidcClientRegistry.find(client_id)

      assert_equal "visitor", client.resource_type, "#{client_id} should be visitor type"
    end
  end

  test "authenticate returns false when secret_credentials are not configured" do
    assert_not OidcClientRegistry.authenticate("core_app", "any_secret_credential")
  end

  test "find resolves secret_credential from flat credential key" do
    with_oidc_client_secret_credentials(OIDC_CLIENT_SECRETS_CORE_APP: "core-app-secret_credential") do
      client = OidcClientRegistry.find("core_app")

      assert_equal "core-app-secret_credential", client.client_secret
    end
  end

  test "authenticate uses flat credential key" do
    with_oidc_client_secret_credentials(OIDC_CLIENT_SECRETS_ACME_ORG: "acme-org-secret_credential") do
      assert OidcClientRegistry.authenticate("acme_org", "acme-org-secret_credential")
      assert_not OidcClientRegistry.authenticate("acme_org", "wrong-secret_credential")
    end
  end

  test "authenticate returns false for blank secret_credential" do
    assert_not OidcClientRegistry.authenticate("core_app", "")
    assert_not OidcClientRegistry.authenticate("core_app", nil)
  end

  test "client_ids returns all registered client IDs" do
    ids = OidcClientRegistry.client_ids

    assert_includes ids, "core_app"
    assert_includes ids, "acme_org"
    assert_equal 18, ids.size
  end

  test "visitor account does not expose ambiguous token endpoint auth method" do
    client = OidcClientRegistry.find!("core_app")

    assert_not_respond_to client, :token_endpoint_auth_method
  end

  test "acme and core clients expose registered private_key_jwt namespaces" do
    expectations = {
      "acme_app" => "ACME_APP",
      "acme_com" => "ACME_COM",
      "acme_org" => "ACME_ORG",
      "core_app" => "CORE_APP",
      "core_com" => "CORE_COM",
      "core_org" => "CORE_ORG",
    }

    expectations.each do |client_id, namespace|
      client = OidcClientRegistry.find!(client_id)

      assert_equal "private_key_jwt", client.registered_token_endpoint_auth_method
      assert_predicate client, :private_key_jwt_client?
      assert_predicate client, :confidential_client?
      assert_not_predicate client, :public_client?
      assert_equal namespace, client.jwt_namespace
    end
  end

  test "docs app has no registered auth method and remains confidential" do
    client = OidcClientRegistry.find!("docs_app")

    assert_predicate client.client_secret, :blank?
    assert_nil client.registered_token_endpoint_auth_method
    assert_not_predicate client, :public_client?
    assert_predicate client, :confidential_client?
    assert_equal "client_secret_post", client.metadata_token_endpoint_auth_method
  end

  test "explicit registered none client is public" do
    client = visitor_account(registered_token_endpoint_auth_method: "none", client_secret: nil)

    assert_predicate client, :public_client?
    assert_not_predicate client, :confidential_client?
  end

  test "missing registered auth method with blank secret remains confidential" do
    client = visitor_account(registered_token_endpoint_auth_method: nil, client_secret: "")

    assert_not_predicate client, :public_client?
    assert_predicate client, :confidential_client?
  end

  test "core clients are registered to regional redirect hosts" do
    expectations = {
      "core_app" => {
        host: ENV.fetch("CORE_SERVICE_URL", "www.jp.umaxica.app"),
        aud: "umaxica-core-app",
        resource_type: "client",
      },
      "core_com" => {
        host: ENV.fetch("CORE_CORPORATE_URL", "www.jp.umaxica.com"),
        aud: "umaxica-core-com",
        resource_type: "visitor",
      },
      "core_org" => {
        host: ENV.fetch("CORE_STAFF_URL", "www.jp.umaxica.org"),
        aud: "umaxica-core-org",
        resource_type: "operator",
      },
    }

    expectations.each do |client_id, expected|
      client = OidcClientRegistry.find!(client_id)
      redirect_uri = URI.parse(client.redirect_uris.fetch(0))

      assert_equal expected[:host], redirect_uri.host, "#{client_id} redirect host is not regional"
      assert_equal "/auth/callback", redirect_uri.path
      assert_equal expected[:aud], client.aud
      assert_equal expected[:resource_type], client.resource_type
      assert_equal [expected[:host]], client.domains
    end
  end

  test "acme clients are registered to same surface redirect hosts" do
    expectations = {
      "acme_app" => {
        host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
        aud: "umaxica-acme-app",
        resource_type: "client",
      },
      "acme_com" => {
        host: ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"),
        aud: "umaxica-acme-com",
        resource_type: "visitor",
      },
      "acme_org" => {
        host: ENV.fetch("ACME_STAFF_URL", "www.org.localhost"),
        aud: "umaxica-acme-org",
        resource_type: "operator",
      },
    }

    expectations.each do |client_id, expected|
      client = OidcClientRegistry.find!(client_id)
      redirect_uri = URI.parse(client.redirect_uris.fetch(0))

      assert_equal expected[:host], redirect_uri.host, "#{client_id} redirect host is cross-surface"
      assert_equal "/auth/callback", redirect_uri.path
      assert_equal expected[:aud], client.aud
      assert_equal expected[:resource_type], client.resource_type
      assert_equal [expected[:host]], client.domains
    end
  end

  private

  def visitor_account(overrides = {})
    OidcClientRegistry::VisitorAccount.new(
      client_id: "test_client",
      client_secret: "secret",
      redirect_uris: ["https://client.example/auth/callback"],
      aud: "test-audience",
      resource_type: "client",
      name: "Test Client",
      domains: ["client.example"],
      registered_token_endpoint_auth_method: "client_secret_post",
      metadata_token_endpoint_auth_method: "client_secret_post",
      jwt_namespace: nil,
      **overrides,
    )
  end
end
