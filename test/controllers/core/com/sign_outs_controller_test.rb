# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class Core::Com::SignOutsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_CORE_CORPORATE_URL", "core.com.localhost")
    host! @host
  end

  test "get sign out renders confirmation without mutation" do
    visitor = create_verified_visitor_with_email(email_address: "core-com-#{SecureRandom.hex(4)}@example.com")
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    satisfy_visitor_verification(token)

    get edit_core_com_sign_out_url(ri: "jp"), headers: {
      "X-TEST-CURRENT-RESOURCE" => visitor.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :success
    assert_select "form[action*=?][method=?]", core_com_sign_out_path, "post"
    assert_predicate token.reload, :currently_usable?
  end

  test "post sign out redirects to acme oidc logout with completion state" do
    visitor = create_verified_visitor_with_email(email_address: "core-com-#{SecureRandom.hex(4)}@example.com")
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    satisfy_visitor_verification(token)

    post core_com_sign_out_url(ri: "jp"), headers: {
      "X-TEST-CURRENT-RESOURCE" => visitor.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :success
    assert_select "form#sign-out-handoff-form[method=?]", "post", count: 1
    location = URI.parse(css_select("form#sign-out-handoff-form").first["action"])
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal ENV.fetch("PRIVATE_ACME_CORPORATE_URL", "www.com.localhost"), location.host
    assert_equal "/oidc/logout", location.path
    assert_predicate query["id_token_hint"], :present?
    assert_equal complete_core_com_sign_out_url(ri: "jp", protocol: "https"), query["post_logout_redirect_uri"]
    assert_predicate query["logout_challenge"], :present?
  end

  test "complete sign out consumes the state and renders completion" do
    visitor = create_verified_visitor_with_email(email_address: "core-com-#{SecureRandom.hex(4)}@example.com")
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    satisfy_visitor_verification(token)

    post core_com_sign_out_url(ri: "jp"), headers: {
      "X-TEST-CURRENT-RESOURCE" => visitor.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    get complete_core_com_sign_out_url(ri: "jp")

    assert_response :success
    assert_select "h1", text: I18n.t("sign.shared.sign_out.completed_title")
  end
end
