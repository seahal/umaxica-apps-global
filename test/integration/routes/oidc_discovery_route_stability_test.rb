# typed: false
# frozen_string_literal: true

require "test_helper"

# Guards that every path advertised in the OIDC discovery document resolves in
# the Rails router for the corresponding surface host.  A route rename that
# updates acme.rb but not OidcIssuer - or vice versa - will fail here before
# any RP ever tries to use the stale URL.
#
# This test is the bridge between:
#   - test/services/oidc/discovery_document_test.rb  (content structure)
#   - test/integration/routes/acme_route_contract_test.rb  (literal paths)
class OidcDiscoveryRouteStabilityTest < ActionDispatch::IntegrationTest
  fixtures_none!

  SURFACES = [
    { resource_type: "client",   host_env: "ACME_SERVICE_URL",   default_host: "www.app.localhost" },
    { resource_type: "visitor",  host_env: "ACME_CORPORATE_URL", default_host: "www.com.localhost" },
    { resource_type: "operator", host_env: "ACME_STAFF_URL",     default_host: "www.org.localhost" },
  ].freeze

  # HTTP method for each discovery document endpoint key.
  # Matches the HTTP methods registered in config/routes/acme.rb.
  ENDPOINT_ROUTE_METHODS = {
    authorization_endpoint: :get,
    token_endpoint: :post,
    userinfo_endpoint: :get,
    jwks_uri: :get,
    revocation_endpoint: :post,
    end_session_endpoint: :get,
  }.freeze

  SURFACES.each do |surface|
    ENDPOINT_ROUTE_METHODS.each do |key, http_method|
      test "#{surface[:resource_type]} discovery #{key} resolves in Rails router" do
        host = ENV.fetch(surface[:host_env], surface[:default_host])
        document = OidcDiscoveryDocument.for_resource_type(surface[:resource_type])
        endpoint_url = document.fetch(key)
        path = URI.parse(endpoint_url).path

        result = Rails.application.routes.recognize_path(
          "http://#{host}#{path}",
          method: http_method,
        )

        assert_predicate result[:controller], :present?,
                         "#{surface[:resource_type]} #{key} path #{path.inspect} must resolve on #{host}"
      end
    end

    test "#{surface[:resource_type]} discovery issuer host matches configured Acme host" do
      host = ENV.fetch(surface[:host_env], surface[:default_host])
      document = OidcDiscoveryDocument.for_resource_type(surface[:resource_type])
      issuer_host = URI.parse(document.fetch(:issuer)).host

      assert_equal host, issuer_host,
                   "#{surface[:resource_type]} issuer host must equal the configured Acme surface host"
    end

    test "#{surface[:resource_type]} all discovery endpoint URLs share the issuer as prefix" do
      document = OidcDiscoveryDocument.for_resource_type(surface[:resource_type])
      issuer = document.fetch(:issuer)

      ENDPOINT_ROUTE_METHODS.each_key do |key|
        endpoint = document.fetch(key)

        assert endpoint.start_with?(issuer),
               "#{surface[:resource_type]} #{key} (#{endpoint}) must be prefixed by issuer (#{issuer})"
      end
    end
  end
end
