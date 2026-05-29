# typed: false
# frozen_string_literal: true

require "test_helper"

class Oidc::DiscoveryDocumentTest < ActiveSupport::TestCase
  test "builds app surface discovery from the issuer contract" do
    document = Oidc::DiscoveryDocument.for_resource_type("client")

    assert_equal Oidc::Issuer.for_resource_type("client"), document.fetch(:issuer)
    assert_equal "#{document.fetch(:issuer)}/oauth/authorize", document.fetch(:authorization_endpoint)
    assert_equal "#{document.fetch(:issuer)}/oauth/token", document.fetch(:token_endpoint)
    assert_equal "#{document.fetch(:issuer)}/oauth/userinfo", document.fetch(:userinfo_endpoint)
    assert_equal "#{document.fetch(:issuer)}/.well-known/jwks.json", document.fetch(:jwks_uri)
    assert_equal ["code"], document.fetch(:response_types_supported)
    assert_equal ["S256"], document.fetch(:code_challenge_methods_supported)
  end
end
