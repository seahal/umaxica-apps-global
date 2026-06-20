# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::SignOutsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_token_kinds

  setup do
    host! ENV.fetch("BASE_SERVICE_URL", "base-jp.umaxica.app")
  end

  test "get sign out renders confirmation without mutation" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    get base_app_sign_out_url(ri: "jp"), headers: {
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :success
    assert_select "form[action=?][method=?]", base_app_sign_out_path, "post"
    assert_predicate token.reload, :currently_usable?
  end

  test "post sign out redirects to acme oidc logout with 307" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post base_app_sign_out_url(ri: "jp"), headers: {
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :temporary_redirect
    location = URI.parse(response.location)

    assert_equal ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), location.host
    assert_equal "/oidc/logout", location.path
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_predicate query["id_token_hint"], :present?
    assert_equal base_app_root_url, query["post_logout_redirect_uri"]
  end
end
