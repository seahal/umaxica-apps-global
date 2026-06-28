# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Com::Sign::OutsControllerTest < ActionDispatch::IntegrationTest
  test "sign com sign-out ceremony routes are retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("AUTH_CORPORATE_URL", "auth.com.localhost")}/sign/out/confirmation",
        method: :get,
      )
    end
  end

  test "get sign out renders confirmation and post starts RP logout" do
    host = ENV.fetch("AUTH_CORPORATE_URL", "auth.com.localhost")
    acme_host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    visitor = create_verified_visitor_with_email(email_address: "sign-com-#{SecureRandom.hex(4)}@example.com")
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    satisfy_visitor_verification(token)
    host! host

    get edit_auth_com_sign_out_url(ri: "jp", host: host), headers: {
      "X-TEST-CURRENT-RESOURCE" => visitor.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :success
    assert_select "form[action='#{auth_com_sign_out_path(ri: "jp")}'] input[name=_method][value=delete]"

    post auth_com_sign_out_url(ri: "jp", host: host), headers: {
      "X-TEST-CURRENT-RESOURCE" => visitor.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :success
    assert_select "form#sign-out-handoff-form[method=?]", "post", count: 1
    location = URI.parse(css_select("form#sign-out-handoff-form").first["action"])
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal acme_host, location.host
    assert_equal "/oidc/logout", location.path
    assert_predicate query["id_token_hint"], :present?
    assert_equal complete_auth_com_sign_out_url(ri: "jp", host: host),
                 query["post_logout_redirect_uri"]
    assert_predicate query["state"], :present?
  end

  test "delete sign out cancels the pending logout and keeps the current session" do
    host = ENV.fetch("AUTH_CORPORATE_URL", "auth.com.localhost")
    visitor = create_verified_visitor_with_email(email_address: "sign-com-cancel-#{SecureRandom.hex(4)}@example.com")
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    satisfy_visitor_verification(token)
    transaction =
      AcmeLogoutTransactionCoordinator.issue!(
        origin_surface: "sign",
        initiating_client_id: "sign-rp",
        completion_url: AcmeLogoutTransactionCoordinator.completion_url_for(
          origin_surface: "sign",
          ri: "jp",
          surface: "com",
        ),
        surface: "com",
        ri: "jp",
      ).transaction
    host! host

    delete auth_com_sign_out_url(ri: "jp", host: host, logout_challenge: transaction.logout_challenge), headers: {
      "X-TEST-CURRENT-RESOURCE" => visitor.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :see_other
    assert_equal auth_com_root_url(ri: "jp", host: host), response.location
    assert_predicate token.reload, :currently_usable?
    assert_predicate transaction.reload, :failed?

    delete auth_com_sign_out_url(ri: "jp", host: host, logout_challenge: transaction.logout_challenge), headers: {
      "X-TEST-CURRENT-RESOURCE" => visitor.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :see_other
    assert_equal auth_com_root_url(ri: "jp", host: host), response.location
    assert_predicate token.reload, :currently_usable?
    assert_predicate transaction.reload, :failed?
  end
end
