# typed: false
# frozen_string_literal: true

require "test_helper"

class SecurityHeadersTest < ActionDispatch::IntegrationTest
  test "production-like ssl middleware emits conservative hsts header" do
    app = ->(_env) { [200, { "Content-Type" => "text/plain" }, ["OK"]] }
    ssl = ActionDispatch::SSL.new(
      app,
      hsts: {
        expires: 365.days,
        subdomains: false,
        preload: false,
      },
    )

    response = Rack::MockRequest.new(ssl).get("https://example.test/health")

    assert_equal "max-age=31536000", response["Strict-Transport-Security"]
  end

  test "content security policy and permissions policy are enforced" do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")

    get sign_app_edge_v0_health_url(ri: "jp")

    assert_response :success
    assert_nil response.headers["Content-Security-Policy-Report-Only"]
    assert_includes response.headers["Content-Security-Policy"], "default-src 'self'"
    assert_includes response.headers["Content-Security-Policy"], "object-src 'none'"
    assert_includes response.headers["Content-Security-Policy"],
                    "form-action 'self' https://accounts.google.com https://appleid.apple.com"
    assert_includes response.headers["Content-Security-Policy"], "script-src 'self' https://challenges.cloudflare.com"
    assert_no_match(/script-src[^;]*\shttps:(?:\s|;|$)/, response.headers["Content-Security-Policy"])
    assert_not_includes response.headers["Content-Security-Policy"], "'unsafe-inline'"
    assert_equal "credentialless", response.headers["Cross-Origin-Embedder-Policy"]
    assert_equal "same-origin", response.headers["Cross-Origin-Opener-Policy"]
    assert_equal "same-origin", response.headers["Cross-Origin-Resource-Policy"]
    assert_nil response.headers["Feature-Policy"]
    assert_includes response.headers["Permissions-Policy"], "camera=()"
    assert_includes response.headers["Permissions-Policy"], "geolocation=()"
    assert_includes response.headers["Permissions-Policy"], "microphone=()"
    assert_includes response.headers["Permissions-Policy"], "publickey-credentials-get=(self)"
    assert_not_includes response.headers["Permissions-Policy"], "publickey-credentials-create"
    assert_no_match(/,\s+/, response.headers["Permissions-Policy"])
  end

  test "acme app root does not load turnstile script until a form needs it" do
    host! ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")

    get acme_app_root_url(ri: "jp")

    assert_response :success
    assert_no_match(/challenges\.cloudflare\.com\/turnstile/, response.body)
  end
end
