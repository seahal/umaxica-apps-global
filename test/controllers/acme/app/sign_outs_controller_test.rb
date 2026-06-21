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

  test "post sign out revokes the current session and reaches completion" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post acme_app_sign_out_url(host: @host, ri: "jp"), headers: {
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :see_other
    assert_predicate token.reload, :revoked?

    follow_redirect!

    assert_response :success
    assert_select "h1", text: I18n.t("sign.shared.sign_out.completed_title")
  end

  test "post sign out without a resolved session renders friendly completion" do
    post acme_app_sign_out_url(host: @host, ri: "jp")

    assert_response :success
    assert_select "h1", text: I18n.t("sign.shared.sign_out.completed_title")
  end
end
