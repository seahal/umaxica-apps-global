# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialCallbackGuardTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  fixtures :users, :user_statuses

  setup do
    OmniAuth.config.test_mode = true
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
  end

  teardown do
    OmniAuth.config.mock_auth[:google_app] = nil
    OmniAuth.config.mock_auth[:apple] = nil
  end

  test "callback phase rejects when state is missing" do
    setup_google_mock_auth(uid: "callback_google_missing_state_#{SecureRandom.hex(4)}")
    user = users(:one)
    prepare_callback_flow(provider: "google_app", user: user)

    get sign_app_auth_callback_url(provider: "google_app", ri: "jp"),
        headers: callback_headers.merge(as_user_headers(user, host: @host))

    assert_response :forbidden
    assert_equal new_sign_app_in_url(ri: "jp"), response.location
  end

  test "callback phase rejects when state mismatches" do
    setup_google_mock_auth(uid: "callback_google_bad_state_#{SecureRandom.hex(4)}")
    user = users(:one)
    prepare_callback_flow(provider: "google_app", user: user)

    get sign_app_auth_callback_url(provider: "google_app", ri: "jp", state: "invalid_state"),
        headers: callback_headers.merge(as_user_headers(user, host: @host))

    assert_response :forbidden
  end

  test "callback phase rejects when state is expired" do
    setup_google_mock_auth(uid: "callback_google_expired_state_#{SecureRandom.hex(4)}")
    user = users(:one)
    state = prepare_callback_flow(provider: "google_app", user: user)

    travel_to 6.minutes.from_now do
      get sign_app_auth_callback_url(provider: "google_app", ri: "jp", state: state),
          headers: callback_headers.merge(as_user_headers(user, host: @host))
    end

    assert_response :forbidden
  end

  test "callback phase rejects reused state" do
    setup_google_mock_auth(uid: "callback_google_reused_state_#{SecureRandom.hex(4)}")
    user = users(:one)
    state = prepare_callback_flow(provider: "google_app", user: user)

    get sign_app_auth_callback_url(provider: "google_app", ri: "jp", state: state),
        headers: callback_headers.merge(as_user_headers(user, host: @host))

    assert_response :redirect

    setup_google_mock_auth(uid: "callback_google_reused_state_2_#{SecureRandom.hex(4)}")
    get sign_app_auth_callback_url(provider: "google_app", ri: "jp", state: state),
        headers: callback_headers.merge(as_user_headers(user, host: @host))

    assert_response :forbidden
  end

  test "callback phase rejects host mismatch" do
    setup_google_mock_auth(uid: "callback_google_host_mismatch_#{SecureRandom.hex(4)}")
    user = users(:one)
    state = prepare_callback_flow(provider: "google_app", user: user)

    get sign_app_auth_callback_url(provider: "google_app", ri: "jp", state: state),
        headers: callback_headers(host: "#{@host}:444").merge(as_user_headers(user, host: "#{@host}:444"))

    assert_response :forbidden
  end

  test "callback phase rejects bad callback method" do
    setup_google_mock_auth(uid: "callback_google_bad_method_#{SecureRandom.hex(4)}")
    user = users(:one)
    state = prepare_callback_flow(provider: "google_app", user: user)

    post sign_app_auth_callback_url(provider: "google_app", ri: "jp", state: state),
         headers: callback_headers.merge(as_user_headers(user, host: @host))

    assert_response :forbidden
  end

  test "callback phase does not reject google origin header from provider domain" do
    setup_google_mock_auth(uid: "callback_google_provider_origin_#{SecureRandom.hex(4)}")
    user = users(:one)
    state = prepare_callback_flow(provider: "google_app", user: user)

    get sign_app_auth_callback_url(provider: "google_app", ri: "jp", state: state),
        headers: callback_headers(origin: "https://accounts.google.com")
          .merge(as_user_headers(user, host: @host))

    assert_response :redirect
    assert_not_equal :forbidden, response.status
  end

  test "callback phase enforces apple POST/GET and google GET" do
    setup_google_mock_auth(uid: "callback_google_bad_method_post_#{SecureRandom.hex(4)}")
    user = users(:one)
    state = prepare_callback_flow(provider: "google_app", user: user)

    post sign_app_auth_callback_url(provider: "google_app", ri: "jp", state: state),
         headers: callback_headers.merge(as_user_headers(user, host: @host))

    assert_response :forbidden
  end

  test "module helpers normalize methods, hosts, and origins" do
    assert SocialCallbackGuard.allowed_request_method?("google_app", "GET")
    assert SocialCallbackGuard.allowed_callback_method?("apple", "POST")
    assert SocialCallbackGuard.allowed_callback_method?("apple", "GET")
    assert_equal "id.app.localhost", SocialCallbackGuard.normalize_host_port("https://id.app.localhost")
    assert_equal "id.app.localhost:444", SocialCallbackGuard.normalize_host_port("https://id.app.localhost:444")
    assert_nil SocialCallbackGuard.normalize_host_port("::not a uri::")
    assert_equal "https://id.app.localhost", SocialCallbackGuard.normalize_origin("https://id.app.localhost")
    assert_equal "https://id.app.localhost:444", SocialCallbackGuard.normalize_origin("https://id.app.localhost:444/path")
    assert_nil SocialCallbackGuard.normalize_origin("ftp://id.app.localhost")
    assert_equal "https://id.app.localhost", SocialCallbackGuard.sanitize_source_header("https://id.app.localhost/path")
  end

  test "request phase helpers derive source, enforce state, and reject bad methods" do
    env = Rack::MockRequest.env_for(
      "https://#{@host}/auth/google_app?foo=bar",
      "REQUEST_METHOD" => "GET",
      "HTTP_ORIGIN" => "https://#{@host}",
      "rack.session" => {},
    )

    source, normalized = SocialCallbackGuard.normalized_request_source(Rack::Request.new(env))

    assert_equal :origin, source
    assert_equal "https://#{@host}", normalized

    SocialCallbackGuard.ensure_state_query_param!(env, Rack::Request.new(env), "google_app")

    assert_includes env["QUERY_STRING"], "state="
    assert_equal "google_app", env["rack.session"][SocialCallbackGuard::SOCIAL_STATE_PROVIDER_SESSION_KEY]

    env_with_state = Rack::MockRequest.env_for(
      "https://#{@host}/auth/google_app?state=known",
      "REQUEST_METHOD" => "GET",
      "HTTP_ORIGIN" => "https://#{@host}",
      "rack.session" => {},
    )

    assert_nil SocialCallbackGuard.verify_request_phase!(env_with_state)
    assert_equal "known", env_with_state["rack.session"][SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY]

    rejected = SocialCallbackGuard.verify_request_phase!(
      Rack::MockRequest.env_for(
        "https://#{@host}/auth/google_app",
        "REQUEST_METHOD" => "DELETE",
        "HTTP_ORIGIN" => "https://#{@host}",
        "rack.session" => {},
      ),
    )

    assert_equal 403, rejected.first
  end

  private

  def prepare_callback_flow(provider:, user:)
    get(
      sign_app_social_start_url(provider: provider, intent: "link", ri: "jp"),
      headers: as_user_headers(user, host: @host),
    )

    assert_response :redirect
    uri = URI.parse(response.location)
    Rack::Utils.parse_nested_query(uri.query.to_s)["state"]
  end

  def callback_headers(host: @host, origin: nil, referer: nil)
    headers = { "Host" => host, "X-STRICT-SOCIAL-STATE" => "1" }
    headers["Origin"] = origin if origin
    headers["Referer"] = referer if referer
    headers
  end

  def setup_google_mock_auth(uid:)
    OmniAuth.config.mock_auth[:google_app] = OmniAuth::AuthHash.new(
      provider: "google_app",
      uid: uid,
      info: { image: "https://example.com/image.jpg" },
      credentials: {
        token: "google_token_#{SecureRandom.hex(8)}",
        refresh_token: "refresh_token",
        expires_at: 1.week.from_now.to_i,
      },
    )
  end

  def setup_apple_mock_auth(uid:)
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: uid,
      info: {},
      credentials: {
        token: "apple_token_#{SecureRandom.hex(8)}",
        expires_at: 1.week.from_now.to_i,
      },
    )
  end
end
