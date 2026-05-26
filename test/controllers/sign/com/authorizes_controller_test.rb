# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::AuthorizesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    ApplicationRecord.clear_fixed_id_seed_cache!
    @visitor = create_verified_visitor_with_email(email_address: "oidc-authorize-#{SecureRandom.hex(4)}@example.com")
    @visitor.visitor_telephones.create!(
      number: "+1000000#{SecureRandom.random_number(10_000).to_s.rjust(4, "0")}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    @code_verifier = SecureRandom.urlsafe_base64(32)
    @code_challenge = Base64.urlsafe_encode64(
      Digest::SHA256.digest(@code_verifier),
      padding: false,
    )
    @client = Oidc::ClientRegistry.find("core_com")
    @redirect_uri = @client.redirect_uris.first
  end

  test "redirects to login when not authenticated" do
    get sign_com_oauth_authorization_url(
      host: @host,
      params: authorize_params,
    ), headers: browser_headers

    assert_response :redirect
  end

  test "redirects to sign up when not authenticated and screen_hint is signup" do
    get sign_com_oauth_authorization_url(
      host: @host,
      params: authorize_params.merge(screen_hint: "signup"),
    ), headers: browser_headers

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(uri.query)

    assert_equal "/sign/up/new", uri.path
    assert_equal "jp", query["ri"]
  end

  test "redirects to callback with code when authenticated" do
    get sign_com_oauth_authorization_url(
      host: @host,
      params: authorize_params,
    ), headers: as_visitor_headers(@visitor, host: @host)

    assert_response :redirect
    uri = URI.parse(response.headers["Location"])
    query = URI.decode_www_form(uri.query).to_h

    assert_predicate query["code"], :present?, "Should include authorization code"
    assert_equal "test_state", query["state"]
  end

  test "returns error for missing client_id" do
    get sign_com_oauth_authorization_url(
      host: @host,
      params: authorize_params.except(:client_id),
    ), headers: as_visitor_headers(@visitor, host: @host)

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body["error"]
  end

  test "returns error for unknown client_id" do
    get sign_com_oauth_authorization_url(
      host: @host,
      params: authorize_params.merge(client_id: "unknown"),
    ), headers: as_visitor_headers(@visitor, host: @host)

    assert_response :bad_request
    assert_equal "unauthorized_client", response.parsed_body["error"]
  end

  test "returns error for invalid redirect_uri" do
    get sign_com_oauth_authorization_url(
      host: @host,
      params: authorize_params.merge(redirect_uri: "https://evil.com/cb"),
    ), headers: as_visitor_headers(@visitor, host: @host)

    assert_response :bad_request
  end

  test "returns error without code_challenge" do
    get sign_com_oauth_authorization_url(
      host: @host,
      params: authorize_params.except(:code_challenge),
    ), headers: as_visitor_headers(@visitor, host: @host)

    assert_response :bad_request
  end

  test "returns error for non-S256 code_challenge_method" do
    get sign_com_oauth_authorization_url(
      host: @host,
      params: authorize_params.merge(code_challenge_method: "plain"),
    ), headers: as_visitor_headers(@visitor, host: @host)

    assert_response :bad_request
  end

  test "creates authorization code record with visitor_id" do
    assert_difference "VisitorAuthorizationCode.count", 1 do
      get sign_com_oauth_authorization_url(
        host: @host,
        params: authorize_params,
      ), headers: as_visitor_headers(@visitor, host: @host)

      assert_response :redirect
    end

    code = VisitorAuthorizationCode.last

    assert_equal @visitor.id, code.visitor_id
    assert_not_nil code.visitor_id
  end

  private

  def authorize_params
    {
      response_type: "code",
      client_id: "core_com",
      redirect_uri: @redirect_uri,
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
      state: "test_state",
      nonce: "test_nonce",
      ri: "jp",
    }
  end
end
