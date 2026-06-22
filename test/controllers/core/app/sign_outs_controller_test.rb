# typed: false
# frozen_string_literal: true

require "test_helper"

class Core::App::SignOutsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_token_kinds

  setup do
    host! ENV.fetch("CORE_SERVICE_URL", "www-jp.umaxica.app")
  end

  test "get sign out renders confirmation without mutation" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    get edit_core_app_sign_out_url(ri: "jp"), headers: {
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :success
    assert_select "form[action*=?][method=?]", core_app_sign_out_path, "post"
    assert_predicate token.reload, :currently_usable?
  end

  test "post sign out redirects to acme oidc logout with completion state" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post core_app_sign_out_url(ri: "jp"), headers: {
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :see_other
    location = URI.parse(jump_rt_url_from_location(response.location))
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), location.host
    assert_equal "/oidc/logout", location.path
    assert_predicate query["logout_challenge"], :present?
    assert_equal "jp", query["ri"]
  end

  test "post sign out without region uses the default completion region" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post core_app_sign_out_url, headers: {
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :see_other
    location = URI.parse(jump_rt_url_from_location(response.location))
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), location.host
    assert_equal "/oidc/logout", location.path
    assert_predicate query["logout_challenge"], :present?
    assert_equal RequestContextContract.default_region, query["ri"]
    assert_includes query.fetch("post_logout_redirect_uri"), "ri=#{RequestContextContract.default_region}"
  end

  test "post sign out can render the acme relay" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post core_app_sign_out_url(ri: "jp"), headers: {
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    challenge = Rack::Utils.parse_nested_query(URI.parse(jump_rt_url_from_location(response.location)).query.to_s)["logout_challenge"]
    get acme_app_oidc_logout_url(
      host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), ri: "jp",
      logout_challenge: challenge,
    )

    assert_response :success
    assert_select "form[action*=?][method=?]", acme_app_oidc_logout_path, "post"
  end
end
