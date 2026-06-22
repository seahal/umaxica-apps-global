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

  test "post sign out redirects to acme oidc logout with logout challenge" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post sign_app_sign_out_url(ri: "jp", host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")),
         headers: as_user_headers(
           user, host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
                 session_public_id: token.public_id,
         )

    assert_response :see_other
    location = URI.parse(jump_rt_url_from_location(response.location))
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), location.host
    assert_equal "/oidc/logout", location.path
    assert_predicate query["logout_challenge"], :present?
    assert_equal "jp", query["ri"]
    assert_predicate token.reload, :revoked?
  end

  test "post sign out can render the acme relay" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post sign_app_sign_out_url(ri: "jp", host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")),
         headers: as_user_headers(
           user, host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
                 session_public_id: token.public_id,
         )

    logout_challenge = Rack::Utils.parse_nested_query(URI.parse(jump_rt_url_from_location(response.location)).query.to_s)["logout_challenge"]

    get acme_app_oidc_logout_url(
      host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
      ri: "jp",
      logout_challenge: logout_challenge,
    )

    assert_response :success
    assert_select "form[action*=?][method=?]", acme_app_oidc_logout_path, "post"

    post acme_app_oidc_logout_url(
      host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
      ri: "jp",
      logout_challenge: logout_challenge,
    )

    assert_response :see_other
    sign_completion = URI.parse(jump_rt_url_from_location(response.location))

    assert_equal ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"), sign_completion.host
    assert_equal "/sign/out/complete", sign_completion.path

    get complete_sign_app_sign_out_url(
      host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
      ri: "jp",
    )

    assert_response :success
    assert_select "h1", text: I18n.t("sign.shared.sign_out.completed_title")
  end

  test "post sign out without a resolved session still starts the coordinated logout" do
    user = clients(:one)

    post sign_app_sign_out_url(ri: "jp", host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")),
         headers: browser_headers.merge(
           "Host" => ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
           "X-TEST-CURRENT-USER" => user.id.to_s,
         )

    assert_response :see_other
    assert_match %r{\Ahttp://#{Regexp.escape(ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"))}/oidc/logout\?logout_challenge=},
                 response.location
  end
end
