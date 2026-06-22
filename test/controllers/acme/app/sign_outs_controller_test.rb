# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::App::Sign::OutsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_token_kinds

  setup do
    @host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    host! @host
  end

  test "new sign out redirects to confirmation without mutation" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    get new_acme_app_sign_out_url(host: @host, ri: "us"), headers: {
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :see_other
    assert_equal edit_acme_app_sign_out_url(host: @host, ri: "us"), response.location
    assert_predicate token.reload, :currently_usable?
  end

  test "edit sign out renders confirmation without mutation" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    get edit_acme_app_sign_out_url(host: @host, ri: "us"), headers: {
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :success
    assert_select "p", text: I18n.t("sign.shared.sign_out.confirm_description")
    assert_select "form[action*=?][method=?]", acme_app_sign_out_path, "post"
    assert_predicate token.reload, :currently_usable?
  end

  test "post sign out starts the coordinated acme -> sign -> acme circuit" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post acme_app_sign_out_url(host: @host, ri: "jp"), headers: {
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :see_other
    assert_predicate token.reload, :revoked?

    sign_edit_uri = URI.parse(jump_rt_url_from_location(response.location))
    sign_challenge = Rack::Utils.parse_nested_query(sign_edit_uri.query.to_s)["logout_challenge"]
    assert_equal ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"), sign_edit_uri.host
    assert_equal "/sign/out/edit", sign_edit_uri.path

    get edit_sign_app_sign_out_url(
      host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
      ri: "jp",
      logout_challenge: sign_challenge,
    )

    assert_response :success
    assert_select "form[action*=?][method=?]", sign_app_sign_out_path, "post"

    post sign_app_sign_out_url(
      host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
      ri: "jp",
      logout_challenge: sign_challenge,
    ), headers: as_user_headers(user, host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"), session_public_id: token.public_id)

    assert_response :see_other
    acme_logout_uri = URI.parse(jump_rt_url_from_location(response.location))
    acme_challenge = Rack::Utils.parse_nested_query(acme_logout_uri.query.to_s)["logout_challenge"]
    assert_equal @host, acme_logout_uri.host
    assert_equal "/oidc/logout", acme_logout_uri.path

    get acme_app_oidc_logout_url(host: @host, ri: "jp", logout_challenge: acme_challenge)

    assert_response :success
    assert_select "form[action*=?][method=?]", acme_app_oidc_logout_path, "post"

    post acme_app_oidc_logout_url(host: @host, ri: "jp", logout_challenge: acme_challenge)

    assert_response :see_other
    assert_equal complete_acme_app_sign_out_url(ri: "jp", host: @host), jump_rt_url_from_location(response.location)

    follow_redirect!

    assert_response :success
    assert_select "h1", text: I18n.t("sign.shared.sign_out.completed_title")
  end

  test "post sign out revokes the current session when only refresh cookie is present" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post acme_app_sign_out_url(host: @host, ri: "jp")

    assert_response :see_other
    assert_predicate token.reload, :revoked?
  end

  test "post sign out without a resolved session still begins the circuit" do
    post acme_app_sign_out_url(host: @host, ri: "jp")

    assert_response :success
    assert_select "h1", text: I18n.t("sign.shared.sign_out.completed_title")
  end
end
