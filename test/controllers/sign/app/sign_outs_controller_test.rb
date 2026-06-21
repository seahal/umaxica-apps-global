# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Sign::OutsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_token_statuses, :client_token_kinds

  test "get sign out renders confirmation without mutation" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    get edit_sign_app_sign_out_url(ri: "jp", host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")),
        headers: as_user_headers(
          user, host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
                session_public_id: token.public_id,
        )

    assert_response :success
    assert_predicate token.reload, :currently_usable?
  end

  test "post sign out redirects to acme oidc logout with completion state" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post sign_app_sign_out_url(ri: "jp", host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")),
         headers: as_user_headers(
           user, host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
                 session_public_id: token.public_id,
         )

    assert_response :temporary_redirect
    location = URI.parse(jump_rt_url_from_location(response.location))
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), location.host
    assert_equal "/oidc/logout", location.path
    assert_predicate query["id_token_hint"], :present?
    assert_equal complete_sign_app_sign_out_url(ri: "jp", host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")),
                 query["post_logout_redirect_uri"]
    assert_predicate query["state"], :present?
    assert_predicate token.reload, :revoked?
  end

  test "complete sign out consumes the state and renders completion" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post sign_app_sign_out_url(ri: "jp", host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")),
         headers: as_user_headers(
           user, host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
                 session_public_id: token.public_id,
         )

    state = Rack::Utils.parse_nested_query(URI.parse(jump_rt_url_from_location(response.location)).query.to_s)["state"]
    get complete_sign_app_sign_out_url(ri: "jp", host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"), state: state)

    assert_response :success
    assert_select "h1", text: I18n.t("sign.shared.sign_out.completed_title")
  end

  test "post sign out without a resolved session renders friendly completion" do
    user = clients(:one)

    post sign_app_sign_out_url(ri: "jp", host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")),
         headers: browser_headers.merge(
           "Host" => ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
           "X-TEST-CURRENT-USER" => user.id.to_s,
         )

    assert_response :success
    assert_select "h1", text: I18n.t("sign.shared.sign_out.completed_title")
  end
end
