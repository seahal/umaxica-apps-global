# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::TokensControllerTest < ActionDispatch::IntegrationTest
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
    @client_secret = "test_secret_for_core_app"
  end

  test "exchanges valid authorization code for tokens" do
    code_record = issue_code!

    with_authenticated_client do
      post sign_app_token_url(host: @host, ri: "jp"), params: token_params(
        code: code_record.code,
      ), headers: browser_headers
    end

    assert_response :ok
    body = response.parsed_body

    assert_predicate body["access_token"], :present?
    assert_predicate body["refresh_token"], :present?
    assert_equal "Bearer", body["token_type"]
    assert_kind_of Integer, body["expires_in"]
  end

  test "sets no-store cache headers on success" do
    code_record = issue_code!

    with_authenticated_client do
      post sign_app_token_url(host: @host, ri: "jp"), params: token_params(
        code: code_record.code,
      ), headers: browser_headers
    end

    assert_response :ok
    assert_match(/no-store/, response.headers["Cache-Control"])
  end

  test "returns error for invalid grant_type" do
    code_record = issue_code!

    with_authenticated_client do
      post sign_app_token_url(host: @host, ri: "jp"), params: token_params(
        code: code_record.code,
        grant_type: "implicit",
      ), headers: browser_headers
    end

    assert_response :bad_request
    body = response.parsed_body

    assert_equal "invalid_request", body["error"]
  end

  test "returns error for nonexistent code" do
    with_authenticated_client do
      post sign_app_token_url(host: @host, ri: "jp"), params: token_params(
        code: "nonexistent_code",
      ), headers: browser_headers
    end

    assert_response :bad_request
    body = response.parsed_body

    assert_equal "invalid_grant", body["error"]
  end

  test "returns error for wrong code_verifier" do
    code_record = issue_code!

    with_authenticated_client do
      post sign_app_token_url(host: @host, ri: "jp"), params: token_params(
        code: code_record.code,
        code_verifier: "wrong_verifier",
      ), headers: browser_headers
    end

    assert_response :bad_request
    body = response.parsed_body

    assert_equal "invalid_request", body["error"]
  end

  test "returns error for expired code" do
    code_record = issue_code!

    travel UserAuthorizationCode::CODE_TTL + 1.second do
      with_authenticated_client do
        post sign_app_token_url(host: @host, ri: "jp"), params: token_params(
          code: code_record.code,
        ), headers: browser_headers
      end

      assert_response :bad_request
      body = response.parsed_body

      assert_equal "invalid_grant", body["error"]
    end
  end

  test "returns error for already consumed code" do
    code_record = issue_code!
    code_record.consume!

    with_authenticated_client do
      post sign_app_token_url(host: @host, ri: "jp"), params: token_params(
        code: code_record.code,
      ), headers: browser_headers
    end

    assert_response :bad_request
    body = response.parsed_body

    assert_equal "invalid_grant", body["error"]
  end

  private

  def token_params(code:, grant_type: "authorization_code", code_verifier: @code_verifier)
    {
      grant_type: grant_type,
      code: code,
      redirect_uri: @redirect_uri,
      client_id: "core_app",
      client_secret: @client_secret,
      code_verifier: code_verifier,
    }
  end

  def issue_code!
    UserAuthorizationCode.issue!(
      user: @user,
      client_id: "core_app",
      redirect_uri: @redirect_uri,
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
    )
  end

  def with_authenticated_client(&block)
    Oidc::ClientRegistry.stub(
      :authenticate, ->(cid, sec) {
                       cid == "core_app" && sec == @client_secret
                     },
    ) do
      block.call
    end
  end
end
