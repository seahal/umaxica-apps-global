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
    host! ENV.fetch("ID_SERVICE_URL")

    get sign_app_health_liveness_url(ri: "jp")

    assert_response :success
    assert_nil response.headers["Content-Security-Policy-Report-Only"]
    assert_includes response.headers["Content-Security-Policy"], "default-src 'self'"
    assert_includes response.headers["Content-Security-Policy"], "object-src 'none'"
    assert_includes response.headers["Content-Security-Policy"],
                    "form-action 'self' https://accounts.google.com https://appleid.apple.com"
    assert_includes response.headers["Content-Security-Policy"],
                    "https://#{ENV.fetch("ACME_SERVICE_URL")}"
    assert_includes response.headers["Content-Security-Policy"],
                    "https://#{ENV.fetch("ACME_CORPORATE_URL")}"
    assert_includes response.headers["Content-Security-Policy"],
                    "https://#{ENV.fetch("ACME_STAFF_URL")}"
    assert_includes response.headers["Content-Security-Policy"],
                    "https://#{ENV.fetch("ID_SERVICE_URL")}"
    assert_includes response.headers["Content-Security-Policy"],
                    "https://#{ENV.fetch("PRIVATE_SIGN_SERVICE_URL")}"
    # The jump gateway must be a valid form-action target: sign-flow form submissions
    # (e.g. the sign-up birthdate checkpoint) finalize by redirecting through it.
    assert_includes response.headers["Content-Security-Policy"],
                    ENV.fetch("JUMP_GATEWAY_URL")
    assert_includes response.headers["Content-Security-Policy"], "connect-src 'self' https: ws: wss:"
    assert_includes response.headers["Content-Security-Policy"], "script-src 'self' 'strict-dynamic'"
    assert_not_includes response.headers["Content-Security-Policy"], "script-src-elem"
    assert_includes response.headers["Content-Security-Policy"], "https://challenges.cloudflare.com"
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
    assert_not_includes response.headers["Permissions-Policy"], "bluetooth"
    assert_not_includes response.headers["Permissions-Policy"], "publickey-credentials-create"
    assert_no_match(/,\s+/, response.headers["Permissions-Policy"])
  end
end
