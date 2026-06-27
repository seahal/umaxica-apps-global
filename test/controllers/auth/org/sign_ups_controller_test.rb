# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Org::SignUpsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
  end

  test "direct entry normalizes to acme org authorization" do
    get sign_org_sign_up_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :redirect

    uri = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal ENV.fetch("ACME_STAFF_URL", "www.org.localhost"), uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_not_equal "jump.umaxica.net", uri.host
    assert_equal "sign-rp", query["client_id"]
    assert_equal "signup", query["screen_hint"]
    assert_nil session[:oidc_authorization_login_challenge]
  end

  test "valid login challenge renders local ceremony" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org",
      intent: "sign_up",
      params: authorize_params(screen_hint: "signup"),
    )

    get sign_org_sign_up_url(ri: "jp", login_challenge: issuance.transaction.login_challenge),
        headers: { "Host" => @host }

    assert_response :success
    assert_equal issuance.transaction.login_challenge, session[:oidc_authorization_login_challenge]
  end

  test "local ceremony does not show registration method choices" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org",
      intent: "sign_up",
      params: authorize_params(screen_hint: "signup"),
    )

    get sign_org_sign_up_url(ri: "jp", login_challenge: issuance.transaction.login_challenge),
        headers: { "Host" => @host }

    assert_response :success
    assert_select "[data-test-id=?]", "registration-method", count: 0
    assert_select "a[href=?]", "/sign/up/email/new?ri=jp", count: 0
    assert_select "form[action*=?]", "/social/auth/google", count: 0
    assert_select "form[action*=?]", "/social/auth/apple", count: 0
  end

  test "local ceremony does not show google signup button even if legacy flag is set" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org",
      intent: "sign_up",
      params: authorize_params(screen_hint: "signup"),
    )

    with_env("ORG_#{"GOOGLE"}_SIGNUP_ENABLED" => "true") do
      get sign_org_sign_up_url(ri: "jp", login_challenge: issuance.transaction.login_challenge),
          headers: { "Host" => @host }
    end

    assert_response :success
    assert_select "form[action*=?]", "/social/auth/google", count: 0
    assert_select "form[action*=?]", "/auth/google", count: 0
  end

  test "local ceremony renders recruit contact and home links" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org",
      intent: "sign_up",
      params: authorize_params(screen_hint: "signup"),
    )

    get sign_org_sign_up_url(ri: "jp", login_challenge: issuance.transaction.login_challenge),
        headers: { "Host" => @host }

    assert_response :success

    acme_host = ENV["ACME_CORPORATE_URL"].presence || "www.com.localhost"

    assert_select "div a[href^=?]", "http://#{acme_host}/",
                  text: I18n.t("sign.org.ups.new.recruit_link_text")

    link = css_select("div a").find { |a| a.text == I18n.t("sign.org.ups.new.recruit_link_text") }

    assert_not_nil link,
                   "Could not find link with text: #{I18n.t("sign.org.ups.new.recruit_link_text").inspect}"
    href = link["href"]

    assert_match(/ri=jp/, href)
  end

  test "direct app-style email sign up route is not available" do
    get "/sign/up/email/new?ri=jp", headers: { "Host" => @host }

    assert_response :not_found
  end

  test "direct app-style telephone sign up route is not available" do
    get "/sign/up/telephone/new?ri=jp", headers: { "Host" => @host }

    assert_response :not_found
  end

  test "legacy invitation email sign up routes are not available" do
    get "/sign/up/invitations/emails/new?ri=jp", headers: { "Host" => @host }

    assert_response :not_found

    post "/sign/up/invitations/emails?ri=jp", headers: { "Host" => @host }

    assert_response :not_found

    get "/sign/up/invitations/emails/invite-code/edit?ri=jp", headers: { "Host" => @host }

    assert_response :not_found

    patch "/sign/up/invitations/emails/invite-code?ri=jp", headers: { "Host" => @host }

    assert_response :not_found
  end

  test "rejects direct entry when logged in" do
    staff = operators(:one)

    get sign_org_sign_up_url(ri: "jp"), headers: as_staff_headers(staff, host: @host)

    assert_response :forbidden
    assert_equal I18n.t("errors.messages.already_authenticated"), response.body
  end

  private

  def authorize_params(screen_hint: nil)
    params = {
      response_type: "code",
      client_id: "core-next-rp",
      redirect_uri: OidcClientRegistry.find!("core-next-rp").redirect_uris.first,
      code_challenge: "challenge",
      code_challenge_method: "S256",
      state: "state",
      nonce: "nonce",
      scope: "openid profile",
    }
    params[:screen_hint] = screen_hint if screen_hint.present?
    params
  end

  def with_env(values)
    original = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    original.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
