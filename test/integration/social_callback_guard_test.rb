# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class SocialCallbackGuardTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  fixtures :clients, :client_statuses, :client_google_identity_statuses

  setup do
    OmniAuth.config.test_mode = true
    @host = ENV.fetch("PRIVATE_AUTH_SERVICE_URL")
    @previous_id_service_url = ENV["PRIVATE_AUTH_SERVICE_URL"]
    ENV["PRIVATE_AUTH_SERVICE_URL"] = @host
    SocialCallbackGuard.instance_variable_set(:@allowed_hosts, nil)
    SocialCallbackGuard.instance_variable_set(:@allowed_request_origins, nil)
  end

  teardown do
    OmniAuth.config.mock_auth[:google_app] = nil
    OmniAuth.config.mock_auth[:apple] = nil
    if @previous_id_service_url.nil?
      ENV.delete("PRIVATE_AUTH_SERVICE_URL")
    else
      ENV["PRIVATE_AUTH_SERVICE_URL"] = @previous_id_service_url
    end
    SocialCallbackGuard.instance_variable_set(:@allowed_hosts, nil)
    SocialCallbackGuard.instance_variable_set(:@allowed_request_origins, nil)
  end

  test "callback phase rejects when state is missing" do
    setup_google_mock_auth(uid: "callback_google_missing_state_#{SecureRandom.hex(4)}")
    user = clients(:one)
    prepare_callback_flow(provider: "google_app", user: user)

    get auth_app_social_google_callback_url(ri: "jp"),
        headers: callback_headers.merge(as_user_headers(user, host: @host))

    assert_response :forbidden
    assert_equal sign_app_sign_in_url(ri: "jp"), response.location
  end

  test "callback phase rejects when state mismatches" do
    setup_google_mock_auth(uid: "callback_google_bad_state_#{SecureRandom.hex(4)}")
    user = clients(:one)
    prepare_callback_flow(provider: "google_app", user: user)

    get auth_app_social_google_callback_url(ri: "jp", state: "invalid_state"),
        headers: callback_headers.merge(as_user_headers(user, host: @host))

    assert_response :forbidden
  end

  test "callback phase rejects when state is expired" do
    setup_google_mock_auth(uid: "callback_google_expired_state_#{SecureRandom.hex(4)}")
    user = clients(:one)
    state = prepare_callback_flow(provider: "google_app", user: user)

    travel_to 6.minutes.from_now do
      get auth_app_social_google_callback_url(ri: "jp", state: state),
          headers: callback_headers.merge(as_user_headers(user, host: @host))
    end

    assert_response :forbidden
  end

  test "callback phase rejects reused state" do
    uid = "callback_google_reused_state_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: uid)
    user = clients(:one)
    create_google_identity!(user: user, uid: uid)
    state = prepare_callback_flow(provider: "google_app", user: user)

    get auth_app_social_google_callback_url(ri: "jp", state: state),
        headers: callback_headers.merge(as_user_headers(user, host: @host))

    assert_response :redirect

    setup_google_mock_auth(uid: "callback_google_reused_state_2_#{SecureRandom.hex(4)}")
    get auth_app_social_google_callback_url(ri: "jp", state: state),
        headers: callback_headers.merge(as_user_headers(user, host: @host))

    assert_response :forbidden
  end

  test "callback phase rejects host mismatch" do
    setup_google_mock_auth(uid: "callback_google_host_mismatch_#{SecureRandom.hex(4)}")
    user = clients(:one)
    state = prepare_callback_flow(provider: "google_app", user: user)

    get auth_app_social_google_callback_url(ri: "jp", state: state),
        headers: callback_headers(host: "#{@host}:444").merge(as_user_headers(user, host: "#{@host}:444"))

    assert_response :forbidden
  end

  test "callback phase rejects bad callback method" do
    setup_google_mock_auth(uid: "callback_google_bad_method_#{SecureRandom.hex(4)}")
    user = clients(:one)
    state = prepare_callback_flow(provider: "google_app", user: user)

    post auth_app_social_google_callback_url(ri: "jp", state: state),
         headers: callback_headers.merge(as_user_headers(user, host: @host))

    assert_response :not_found
  end

  test "callback phase does not reject google origin header from provider domain" do
    uid = "callback_google_provider_origin_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: uid)
    user = clients(:one)
    create_google_identity!(user: user, uid: uid)
    state = prepare_callback_flow(provider: "google_app", user: user)

    get auth_app_social_google_callback_url(ri: "jp", state: state),
        headers: callback_headers(origin: "https://accounts.google.com")
          .merge(as_user_headers(user, host: @host))

    assert_response :redirect
    assert_not_equal :forbidden, response.status
  end

  test "callback phase enforces google GET" do
    setup_google_mock_auth(uid: "callback_google_bad_method_post_#{SecureRandom.hex(4)}")
    user = clients(:one)
    state = prepare_callback_flow(provider: "google_app", user: user)

    post auth_app_social_google_callback_url(ri: "jp", state: state),
         headers: callback_headers.merge(as_user_headers(user, host: @host))

    assert_response :not_found
  end

  test "module helpers normalize methods, hosts, and origins" do
    assert SocialCallbackGuard.allowed_request_method?("google", "GET")
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

  test "allowed hosts includes sign host environment names" do
    SocialCallbackGuard.instance_variable_set(:@allowed_hosts, nil)

    begin
      with_env("PRIVATE_AUTH_SERVICE_URL" => "log.umaxica.app", "SIGN_STAFF_URL" => "log.umaxica.org") do
        SocialCallbackGuard.instance_variable_set(:@allowed_hosts, nil)

        assert_includes SocialCallbackGuard.allowed_hosts, "log.umaxica.app"
        assert_includes SocialCallbackGuard.allowed_hosts, "log.umaxica.org"
      end
    ensure
      SocialCallbackGuard.instance_variable_set(:@allowed_hosts, nil)
    end
  end

  test "request phase helpers derive source, enforce state, and reject bad methods" do
    env = Rack::MockRequest.env_for(
      "https://#{@host}/social/google?foo=bar",
      "REQUEST_METHOD" => "GET",
      "HTTP_ORIGIN" => "https://#{@host}",
      "rack.session" => {},
    )

    source, normalized = SocialCallbackGuard.normalized_request_source(Rack::Request.new(env))

    assert_equal :origin, source
    assert_equal "https://#{@host}", normalized

    SocialCallbackGuard.ensure_state_query_param!(env, Rack::Request.new(env), "google")

    assert_includes env["QUERY_STRING"], "state="
    assert_equal "google", env["rack.session"][SocialCallbackGuard::SOCIAL_STATE_PROVIDER_SESSION_KEY]

    env_with_state = Rack::MockRequest.env_for(
      "https://#{@host}/social/google?state=known",
      "REQUEST_METHOD" => "GET",
      "HTTP_ORIGIN" => "https://#{@host}",
      "rack.session" => {},
    )

    assert_nil SocialCallbackGuard.verify_request_phase!(env_with_state)
    assert_equal "known", env_with_state["rack.session"][SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY]

    rejected = SocialCallbackGuard.verify_request_phase!(
      Rack::MockRequest.env_for(
        "https://#{@host}/social/google",
        "REQUEST_METHOD" => "DELETE",
        "HTTP_ORIGIN" => "https://#{@host}",
        "rack.session" => {},
      ),
    )

    assert_equal 403, rejected.first
  end

  private

  def prepare_callback_flow(provider:, user:)
    normalized_provider = (provider == "apple") ? "apple" : "google"
    seed_social_auth_session(provider: normalized_provider, intent: "login", user: user, ri: "jp")
  end

  def callback_headers(host: @host, origin: nil, referer: nil)
    headers = { "Host" => host, "X-STRICT-SOCIAL-STATE" => "1" }
    headers["Origin"] = origin if origin
    headers["Referer"] = referer if referer
    headers
  end

  def setup_google_mock_auth(uid:)
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google",
      uid: uid,
      info: { image: "https://example.com/image.jpg" },
      credentials: {
        token: "google_token_#{SecureRandom.hex(8)}",
        refresh_token: "refresh_token",
        discarded_at: 1.week.from_now.to_i,
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
        discarded_at: 1.week.from_now.to_i,
      },
    )
  end

  def create_google_identity!(user:, uid:)
    ClientGoogleIdentity.create!(
      user: user,
      uid: uid,
      provider: "google",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      status_id: ClientGoogleIdentityStatus::ACTIVE,
    )
  end

  def with_env(values)
    previous = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end
end
