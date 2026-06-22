# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Org::SignOutsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_token_kinds

  setup do
    host! ENV.fetch("BASE_STAFF_URL", "base.org.localhost")
  end

  test "get sign out renders confirmation without mutation" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    get edit_base_org_sign_out_url(ri: "jp"), headers: {
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :success
    assert_select "form[action*=?][method=?]", base_org_sign_out_path, "post"
    assert_predicate token.reload, :currently_usable?
  end

  test "post sign out redirects to acme oidc logout with completion state" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post base_org_sign_out_url(ri: "jp"), headers: {
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :temporary_redirect
    location = URI.parse(jump_rt_url_from_location(response.location))
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal ENV.fetch("ACME_STAFF_URL", "www.org.localhost"), location.host
    assert_equal "/oidc/logout", location.path
    assert_predicate query["id_token_hint"], :present?
    assert_equal complete_base_org_sign_out_url(ri: "jp"), query["post_logout_redirect_uri"]
    assert_predicate query["state"], :present?
  end

  test "complete sign out consumes the state and renders completion" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post base_org_sign_out_url(ri: "jp"), headers: {
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    state = Rack::Utils.parse_nested_query(URI.parse(jump_rt_url_from_location(response.location)).query.to_s)["state"]
    get complete_base_org_sign_out_url(ri: "jp", state: state)

    assert_response :success
    assert_select "h1", text: I18n.t("sign.shared.sign_out.completed_title")
  end
end
