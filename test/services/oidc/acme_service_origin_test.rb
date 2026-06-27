# typed: false
# frozen_string_literal: true

require "test_helper"

class Oidc::AcmeServiceOriginTest < ActiveSupport::TestCase
  test "normalizes public bare host into a https origin without inventing a port" do
    origin = build_origin("www.umaxica.app", default_scheme: "https")

    assert_equal "https", origin.scheme
    assert_equal "www.umaxica.app", origin.host
    assert_nil origin.port
    assert_equal "https://www.umaxica.app", origin.origin
    assert_equal "https://www.umaxica.app/oauth/authorize", origin.authorization_endpoint
    assert_equal "https://www.umaxica.app/oauth/token", origin.token_endpoint
  end

  test "normalizes host and scheme variants with default ports" do
    origin = build_origin("www.umaxica.app:443", default_scheme: "https")
    explicit = build_origin("https://www.umaxica.app", default_scheme: "https")

    assert_equal "www.umaxica.app", origin.host
    assert_nil origin.port
    assert_equal explicit.origin, origin.origin
    assert_equal explicit.authorization_endpoint(query: { client_id: "base-rails-rp" }),
                 origin.authorization_endpoint(query: { client_id: "base-rails-rp" })
  end

  test "normalizes explicit https origins with default ports" do
    origin = build_origin("https://www.umaxica.app:443", default_scheme: "https")
    explicit = build_origin("https://www.umaxica.app", default_scheme: "https")

    assert_equal explicit.scheme, origin.scheme
    assert_equal explicit.host, origin.host
    assert_nil origin.port
    assert_equal explicit.origin, origin.origin
    assert_equal explicit.token_endpoint, origin.token_endpoint
  end

  test "normalizes localhost origins with explicit ports" do
    origin = build_origin("http://www.app.localhost:3000", default_scheme: "http")

    assert_equal "http", origin.scheme
    assert_equal "www.app.localhost", origin.host
    assert_equal 3000, origin.port
    assert_equal "http://www.app.localhost:3000", origin.origin
    assert_equal "http://www.app.localhost:3000/oauth/authorize", origin.authorization_endpoint
    assert_equal "http://www.app.localhost:3000/oauth/token", origin.token_endpoint
  end

  test "preserves localhost ports and does not invent 3000 for bare hosts" do
    origin = build_origin("www.app.localhost:3001", default_scheme: "http")

    assert_equal "http", origin.scheme
    assert_equal "www.app.localhost", origin.host
    assert_equal 3001, origin.port
    assert_equal "http://www.app.localhost:3001", origin.origin
  end

  test "bare localhost host keeps the host without inventing port 3000" do
    origin = build_origin("www.app.localhost", default_scheme: "http")

    assert_equal "http", origin.scheme
    assert_equal "www.app.localhost", origin.host
    assert_nil origin.port
    assert_equal "http://www.app.localhost", origin.origin
    assert_not_includes origin.origin, ":3000"
  end

  test "rejects invalid origin input" do
    assert_raises(ArgumentError) { build_origin("", default_scheme: "https") }
    assert_raises(ArgumentError) { build_origin("javascript:alert(1)", default_scheme: "https") }
    assert_raises(ArgumentError) { build_origin("https://example.com/path", default_scheme: "https") }
    assert_raises(ArgumentError) { build_origin("https://example.com?x=1", default_scheme: "https") }
  end

  test "directs same-site browser authorize requests and rejects mismatches by reason" do
    origin = build_origin("www.umaxica.app", default_scheme: "https")
    request = test_request(host: "log.umaxica.app", scheme: "https")
    authorize_url =
      origin.authorization_endpoint(
        query: {
          client_id: "base-rails-rp",
          redirect_uri: "https://log.umaxica.app/oidc/callback",
          response_type: "code",
        },
      )

    decision = origin.decision_for_authorize_url(authorize_url, request: request)

    assert_predicate decision, :direct?
    assert_equal "direct_same_site_acme_authorize", decision.reason_code
    assert decision.same_site
    assert_equal "www.umaxica.app", decision.target_host
    assert_nil decision.target_port

    host_mismatch = origin.decision_for_authorize_url(
      "https://evil.example/oauth/authorize?client_id=base-rails-rp",
      request: request,
    )

    assert_equal :jump, host_mismatch.kind
    assert_equal "host_mismatch", host_mismatch.reason_code

    default_port = origin.decision_for_authorize_url(
      "https://www.umaxica.app:443/oauth/authorize?client_id=base-rails-rp",
      request: request,
    )

    assert_predicate default_port, :direct?
    assert_equal "direct_same_site_acme_authorize", default_port.reason_code

    path_mismatch = origin.decision_for_authorize_url(
      "https://www.umaxica.app/oauth/token?client_id=base-rails-rp",
      request: request,
    )

    assert_equal :jump, path_mismatch.kind
    assert_equal "not_acme_authorize", path_mismatch.reason_code

    invalid = origin.decision_for_authorize_url("not-a-url", request: request)

    assert_equal :rejected, invalid.kind
    assert_equal "invalid_url", invalid.reason_code
  end

  test "normalizes same-site authorize URLs across host and port forms" do
    origin = build_origin("www.app.localhost:3000", default_scheme: "http")
    request = test_request(host: "id.app.localhost", scheme: "http")

    assert origin.same_site_authorize_url?(
      "http://www.app.localhost:3000/oauth/authorize?client_id=base-rails-rp",
      request: request,
    )
    assert_not origin.same_site_authorize_url?(
      "http://www.app.localhost/oauth/authorize?client_id=base-rails-rp",
      request: request,
    )
    assert_equal "port_mismatch",
                 origin.same_site_rejection_reason(
                   "http://www.app.localhost/oauth/authorize?client_id=base-rails-rp",
                   request: request,
                 )
  end

  private

  def build_origin(value, default_scheme:)
    Oidc::AcmeServiceOrigin.from(value, default_scheme: default_scheme)
  end

  def test_request(host:, scheme:)
    env = {
      "HTTP_HOST" => host,
      "HTTPS" => ((scheme == "https") ? "on" : "off"),
      "rack.url_scheme" => scheme,
    }
    ActionDispatch::TestRequest.create(env)
  end
end
