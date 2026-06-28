# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::SignOutsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host! @host
  end

  test "new renders confirmation page" do
    user = create_verified_user_with_email(email_address: "base-sign-out-new@example.com")
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    get new_base_app_sign_out_url(host: @host), headers: {
      **as_user_headers(user, host: @host, session_public_id: token.public_id),
    }

    assert_response :success
    assert_select "h1", text: I18n.t("sign.shared.sign_out.title")
  end

  test "post sign out issues logout transaction and redirects to sign receiver" do
    user = create_verified_user_with_email(email_address: "base-sign-out-post@example.com")
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post base_app_sign_out_url(host: @host), headers: browser_headers.merge(
      "Host" => @host,
      **as_user_headers(user, host: @host, session_public_id: token.public_id),
    )

    assert_response :see_other
    location = URI.parse(response.location)

    assert_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"), location.host
    assert_equal "/sign/out", location.path
    assert_predicate Rack::Utils.parse_nested_query(location.query.to_s)["logout_token"], :present?
    assert_predicate token.reload, :revoked?
  end

  test "post sign out without active session redirects to complete" do
    post base_app_sign_out_url(host: @host), headers: browser_headers.merge("Host" => @host)

    assert_response :see_other
    assert_equal complete_base_app_sign_out_url(host: @host, protocol: "https"), response.location
  end
end
