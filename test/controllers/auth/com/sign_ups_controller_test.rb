# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Com::SignUpsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost")
  end

  test "direct entry normalizes to acme com authorization" do
    get auth_com_sign_up_url(ct: "dr", ri: "jp"), headers: default_headers

    assert_response :redirect

    uri = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"), uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_not_equal "jump.umaxica.net", uri.host
    assert_equal "sign-rp", query["client_id"]
    assert_equal "signup", query["screen_hint"]
    assert_nil session[:oidc_authorization_login_challenge]
  end

  test "local ceremony shows email and telephone registration methods" do
    get auth_com_sign_up_url(ct: "dr", ri: "jp", login_challenge: login_challenge), headers: default_headers

    assert_response :success
    assert_select "[data-test-id=?]", "registration-method", count: 2
    assert_select "a[href=?]", new_auth_com_sign_up_email_path(ct: "dr", ri: "jp"), count: 1
    assert_select "a[href=?]", new_auth_com_sign_up_telephone_path(ct: "dr", ri: "jp"), count: 1
  end

  test "does not show social login buttons when flag is off" do
    get auth_com_sign_up_url(ct: "dr", ri: "jp", login_challenge: login_challenge), headers: default_headers

    assert_response :success
    assert_select "form[action*=?]", "/social/auth/google_app/continue", count: 0
    assert_select "form[action*=?]", "/social/auth/apple/continue", count: 0
    assert_select "form[action*=?]", "/social/auth/google", count: 0
    assert_select "form[action*=?]", "/auth/google", count: 0
  end

  test "does not show temporary google signup button when legacy flag is on" do
    with_env("COM_#{"GOOGLE"}_SIGNUP_ENABLED" => "true") do
      get auth_com_sign_up_url(ct: "dr", ri: "jp", login_challenge: login_challenge),
          headers: default_headers
    end

    assert_response :success
    assert_select "form[action*=?]", "/social/auth/google", count: 0
    assert_select "form[action*=?]", "/auth/google", count: 0
  end

  test "rejects direct entry when logged in" do
    visitor = create_verified_visitor_with_email(email_address: "com-up-logged-in@example.com")
    visitor.visitor_telephones.create!(
      number: "+15550002224",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )

    get auth_com_sign_up_url(ri: "jp"), headers: as_visitor_headers(visitor, host: host)

    assert_response :forbidden
    assert_equal I18n.t("errors.messages.already_authenticated"), response.body
  end

  test "sign up entry renders without an active registration" do
    get auth_com_sign_up_url(ri: "jp", login_challenge: login_challenge), headers: default_headers

    assert_response :success
  end

  private

  def login_challenge
    OidcAuthorizationTransactionCoordinator.issue!(
      surface: "com",
      intent: "sign_up",
      params: authorize_params,
    ).transaction.login_challenge
  end

  def authorize_params
    {
      response_type: "code",
      client_id: "core-next-rp",
      redirect_uri: OidcClientRegistry.find!("core-next-rp").redirect_uris.first,
      code_challenge: "challenge",
      code_challenge_method: "S256",
      state: SecureRandom.urlsafe_base64(16),
      nonce: SecureRandom.urlsafe_base64(16),
      scope: "openid profile",
    }
  end

  def default_headers
    { "Host" => host, "HTTPS" => "on" }
  end

  def host
    ENV["SIGN_CORPORATE_URL"] || "id.com.localhost"
  end

  def with_env(values)
    original = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    original.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
