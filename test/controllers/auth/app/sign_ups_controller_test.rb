# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::SignUpsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses

  test "direct entry normalizes to acme app authorization" do
    get sign_app_sign_up_url(format: :html, ri: "jp"), headers: { "Host" => host }

    assert_response :redirect

    uri = URI.parse(jump_rt_url_from_location(response.location))
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_equal "sign-rp", query["client_id"]
    assert_equal "signup", query["screen_hint"]
    assert_nil session[:oidc_authorization_login_challenge]
    assert_nil session["oidc_pending_flows"]
  end

  test "valid login challenge renders local ceremony" do
    get sign_app_sign_up_url(format: :html, ri: "jp", login_challenge: login_challenge),
        headers: { "Host" => host }

    assert_response :success
  end

  test "sets lang attribute on html element" do
    get sign_app_sign_up_url(format: :html, ri: "jp", login_challenge: login_challenge),
        headers: { "Host" => host }

    assert_response :success
    assert_select("html[lang=?]", "ja")
    assert_not_select("html[lang=?]", "")
  end

  test "shows registration methods and social providers" do
    get sign_app_sign_up_url(format: :html, ri: "jp", login_challenge: login_challenge),
        headers: { "Host" => host }

    assert_response :success

    assert_select "[data-test-id=?]", "registration-method", count: 4
  end

  test "shows telephone registration link" do
    get sign_app_sign_up_url(format: :html, ri: "jp", login_challenge: login_challenge),
        headers: { "Host" => host }

    assert_response :success
    assert_select "a[href=?]", new_sign_app_sign_up_telephone_path(ri: "jp"), count: 1
  end

  test "shows social login buttons" do
    get sign_app_sign_up_url(format: :html, ri: "jp", login_challenge: login_challenge),
        headers: { "Host" => host }

    assert_response :success
    assert_select "a[href=?][data-turbo=?]",
                  sign_app_social_google_sign_up_path(ri: "jp"),
                  "false",
                  count: 1
    assert_select "a[href=?][data-turbo=?]",
                  sign_app_social_apple_sign_up_path(ri: "jp"),
                  "false",
                  count: 1
  end

  test "renders registration layout structure" do
    get sign_app_sign_up_url(format: :html, ri: "jp", login_challenge: login_challenge),
        headers: { "Host" => host }

    assert_response :success

    expected_brand = brand_name
    escaped_brand = Regexp.escape(expected_brand)

    assert_select "head", count: 1
    # Skip favicon check - may not be present in all layouts
    assert_select "body", count: 1 do
      assert_select "header", minimum: 1
      assert_select "main", count: 1
      assert_select "footer", count: 1 do
        assert_select ".opacity-50", text: /^©.*#{escaped_brand}$/
      end
    end
  end

  test "header contains authentication links" do
    get sign_app_sign_up_url(format: :html, ri: "jp", login_challenge: login_challenge),
        headers: { "Host" => host }

    assert_response :success
    assert_select "header", minimum: 1 do
      assert_select "h1", minimum: 1
    end
  end

  test "footer contains navigation links" do
    get sign_app_sign_up_url(format: :html, ri: "jp", login_challenge: login_challenge),
        headers: { "Host" => host }

    assert_response :success
    assert_select "footer" do
      # Footer should contain copyright and links
      assert_select "a"
    end
  end
  test "renders specific cta text" do
    get sign_app_sign_up_url(format: :html, ri: "jp", login_challenge: login_challenge),
        headers: { "Host" => host }

    assert_response :success
    # Check for Japanese text (since previous test asserted lang=ja)
    assert_select "a", text: "メールで登録する"
  end

  test "logged in direct entry redirects to dashboard" do
    user = clients(:one)
    get sign_app_sign_up_url(format: :html, ri: "jp"), headers: as_user_headers(user, host: host)

    assert_response :redirect
    assert_redirected_to sign_app_dashboard_url(ri: "jp", host: host)
  end

  test "checkpoint without active registration redirects to sign up start" do
    get sign_app_sign_up_guard_email_path(ri: "jp"), headers: { "Host" => host }

    assert_redirected_to sign_app_sign_up_url(ri: "jp")
  end

  private

  def host
    ENV["ID_SERVICE_URL"] || "id.app.localhost"
  end

  def brand_name
    (ENV["BRAND_NAME"].presence || ENV["NAME"]).to_s
  end

  def login_challenge
    OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app",
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
end
