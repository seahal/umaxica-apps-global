# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcClientRegistryTest < ActiveSupport::TestCase
  fixtures_none!

  test "find returns client config as visitor account" do
    client = OidcClientRegistry.find("base-rails-rp")

    assert_not_nil client
    assert_equal "base-rails-rp", client.client_id
    assert_equal "base-rails-rp", client.aud
    assert client.redirect_uris.any? { |uri| uri.end_with?("/oidc/callback") }
  end

  test "find returns nil for unknown client" do
    client = OidcClientRegistry.find("unknown-client")

    assert_nil client
  end

  test "find! raises for unknown client" do
    assert_raises(OidcClientRegistry::ClientNotFound) do
      OidcClientRegistry.find!("unknown-client")
    end
  end

  test "domains_from_redirect_uris extracts hosts from valid URIs" do
    result = OidcClientRegistry.send(:domains_from_redirect_uris, ["https://example.com/cb", "https://other.test/path"])

    assert_equal 2, result.length
    assert_includes result, "example.com"
    assert_includes result, "other.test"
  end

  test "domains_from_redirect_uris returns empty array for invalid URIs" do
    result = OidcClientRegistry.send(:domains_from_redirect_uris, ["not a valid uri???"])

    assert_empty result
  end

  test "public_host? returns false for loopback hosts" do
    result = OidcClientRegistry.send(:public_host?, "localhost")

    assert_predicate result, :!
  end

  test "public_host? returns true for public hosts" do
    result = OidcClientRegistry.send(:public_host?, "example.com")

    assert_predicate result, :itself
  end

  test "public_host? returns false for invalid URIs" do
    result = OidcClientRegistry.send(:public_host?, "not:::valid")

    assert_predicate result, :!
  end

  test "logout_uri_resource_type returns client for unknown host" do
    result = OidcClientRegistry.send(:logout_uri_resource_type, "https://unknown.example.com/logout")

    assert_equal "client", result
  end

  test "normalize_resource_type normalizes operator aliases" do
    assert_equal "operator", OidcClientRegistry.send(:normalize_resource_type, "operator")
    assert_equal "operator", OidcClientRegistry.send(:normalize_resource_type, "staff")
  end

  test "normalize_resource_type normalizes visitor aliases" do
    assert_equal "visitor", OidcClientRegistry.send(:normalize_resource_type, "visitor")
    assert_equal "visitor", OidcClientRegistry.send(:normalize_resource_type, "customer")
  end

  test "normalize_resource_type defaults unknown types to client" do
    assert_equal "client", OidcClientRegistry.send(:normalize_resource_type, "unknown")
    assert_equal "client", OidcClientRegistry.send(:normalize_resource_type, nil)
  end
end
