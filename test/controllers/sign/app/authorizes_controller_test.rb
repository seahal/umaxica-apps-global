# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::AuthorizesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = users(:one)
    @code_verifier = SecureRandom.urlsafe_base64(32)
    @code_challenge = Base64.urlsafe_encode64(
      Digest::SHA256.digest(@code_verifier),
      padding: false,
    )
    @client = Oidc::ClientRegistry.find("core_app")
    @redirect_uri = @client.redirect_uris.first
  end

  test "redirects to login when not authenticated" do
    get sign_app_authorize_url(
      host: @host,
      params: authorize_params,
    ), headers: browser_headers

    assert_response :redirect
  end

  test "redirects to callback with code when authenticated" do
    get sign_app_authorize_url(
      host: @host,
      params: authorize_params,
    ), headers: as_user_headers(@user, host: @host)

    assert_response :redirect
    location = response.headers["Location"]
    uri = URI.parse(location)
    query = URI.decode_www_form(uri.query).to_h

    assert_predicate query["code"], :present?, "Should include authorization code"
    assert_equal "test_state", query["state"]
  end

  test "returns error for missing client_id" do
    get sign_app_authorize_url(
      host: @host,
      params: authorize_params.except(:client_id),
    ), headers: as_user_headers(@user, host: @host)

    assert_response :bad_request
    body = response.parsed_body

    assert_equal "invalid_request", body["error"]
  end

  test "returns error for unknown client_id" do
    get sign_app_authorize_url(
      host: @host,
      params: authorize_params.merge(client_id: "unknown"),
    ), headers: as_user_headers(@user, host: @host)

    assert_response :bad_request
    body = response.parsed_body

    assert_equal "unauthorized_client", body["error"]
  end

  test "returns error for invalid redirect_uri" do
    get sign_app_authorize_url(
      host: @host,
      params: authorize_params.merge(redirect_uri: "https://evil.com/cb"),
    ), headers: as_user_headers(@user, host: @host)

    assert_response :bad_request
  end

  test "returns error without code_challenge" do
    get sign_app_authorize_url(
      host: @host,
      params: authorize_params.except(:code_challenge),
    ), headers: as_user_headers(@user, host: @host)

    assert_response :bad_request
  end

  test "returns error for non-S256 code_challenge_method" do
    get sign_app_authorize_url(
      host: @host,
      params: authorize_params.merge(code_challenge_method: "plain"),
    ), headers: as_user_headers(@user, host: @host)

    assert_response :bad_request
  end

  test "creates authorization code record" do
    assert_difference "UserAuthorizationCode.count", 1 do
      get sign_app_authorize_url(
        host: @host,
        params: authorize_params,
      ), headers: as_user_headers(@user, host: @host)

      assert_response :redirect
    end
  end

  private

  def authorize_params
    {
      response_type: "code",
      client_id: "core_app",
      redirect_uri: @redirect_uri,
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
      state: "test_state",
      ri: "jp",
    }
  end
end
