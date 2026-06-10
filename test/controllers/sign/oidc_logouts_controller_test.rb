# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::OidcLogoutsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
  end

  test "rejects logout without signed logout request" do
    host! @host

    get "/oidc/logout",
        params: {
          client_id: "acme_app",
          ri: "jp",
        },
        headers: browser_headers.merge("Host" => @host)

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body["error"]
    assert_nil response.location
  end

  test "rejects post logout redirect uri even with signed logout request" do
    host! @host

    get "/oidc/logout",
        params: {
          client_id: "acme_app",
          logout_request: OidcLogoutRequest.issue(client_id: "acme_app", ri: "jp"),
          post_logout_redirect_uri: "https://evil.example/sign/out",
          ri: "jp",
        },
        headers: browser_headers.merge("Host" => @host)

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body["error"]
    assert_nil response.location
  end

  test "signed logout request delegates completion to acme authority" do
    host! @host

    get "/oidc/logout",
        params: {
          client_id: "acme_app",
          logout_request: OidcLogoutRequest.issue(client_id: "acme_app", ri: "jp"),
          ri: "jp",
        },
        headers: browser_headers.merge("Host" => @host)

    assert_response :see_other
    location = URI.parse(response.location)

    assert_equal "/sign/out/completion", location.path
    assert_equal "ri=jp", location.query

    get "/sign/out/completion", params: { ri: "jp" }, headers: browser_headers.merge("Host" => @host)

    assert_response :success
  end

  test "rejects client id mismatch with signed logout request" do
    host! @host

    get "/oidc/logout",
        params: {
          client_id: "acme_org",
          logout_request: OidcLogoutRequest.issue(client_id: "acme_app", ri: "jp"),
          ri: "jp",
        },
        headers: browser_headers.merge("Host" => @host)

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body["error"]
  end

  # Regression: a freshly issued, signature-valid logout_request must
  # only be consumable once. Re-presenting the same token (browser back
  # button, link prefetcher, copy-pasted URL, replay attempt) must be
  # rejected. Rails.cache is :null_store in the test env, so we inject
  # a real MemoryStore for this assertion.
  test "rejects replay of an already-consumed signed logout request" do
    OidcLogoutRequest.replay_store = ActiveSupport::Cache::MemoryStore.new
    host!(@host)
    token = OidcLogoutRequest.issue(client_id: "acme_app", ri: "jp")

    get(
      "/oidc/logout",
      params: { client_id: "acme_app", logout_request: token, ri: "jp" },
      headers: browser_headers.merge("Host" => @host),
    )

    assert_response :see_other

    get(
      "/oidc/logout",
      params: { client_id: "acme_app", logout_request: token, ri: "jp" },
      headers: browser_headers.merge("Host" => @host),
    )

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body["error"]
  ensure
    OidcLogoutRequest.replay_store = nil
  end
end
