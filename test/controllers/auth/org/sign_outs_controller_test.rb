# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class Auth::Org::Sign::OutsControllerTest < ActionDispatch::IntegrationTest
  test "sign org sign-out ceremony routes are retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")}/sign/out/confirmation",
        method: :get,
      )
    end
  end

  test "get sign out renders confirmation and post starts RP logout" do
    host = ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
    acme_host = ENV.fetch("PRIVATE_ACME_STAFF_URL", "www.org.localhost")
    staff = operators(:one)
    token = OperatorToken.create!(staff: staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    satisfy_staff_verification(token)
    host! host

    get edit_auth_org_sign_out_url(ri: "jp", host: host), headers: {
      "X-TEST-CURRENT-STAFF" => staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :success
    assert_select "form[action='#{auth_org_sign_out_path(ri: "jp")}'] input[name=_method][value=delete]"

    post auth_org_sign_out_url(ri: "jp", host: host), headers: {
      "X-TEST-CURRENT-STAFF" => staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :success
    assert_select "form#sign-out-handoff-form[method=?]", "post", count: 1
    location = URI.parse(css_select("form#sign-out-handoff-form").first["action"])
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal acme_host, location.host
    assert_equal "/oidc/logout", location.path
    assert_predicate query["id_token_hint"], :present?
    assert_equal complete_auth_org_sign_out_url(ri: "jp", host: host),
                 query["post_logout_redirect_uri"]
    assert_predicate query["state"], :present?
  end

  test "delete sign out cancels the pending logout and keeps the current session" do
    host = ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
    staff = operators(:one)
    token = OperatorToken.create!(staff: staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    satisfy_staff_verification(token)
    transaction =
      AcmeLogoutTransactionCoordinator.issue!(
        origin_surface: "sign",
        initiating_client_id: "sign-rp",
        completion_url: AcmeLogoutTransactionCoordinator.completion_url_for(
          origin_surface: "sign",
          ri: "jp",
          surface: "org",
        ),
        surface: "org",
        ri: "jp",
      ).transaction
    host! host

    delete auth_org_sign_out_url(ri: "jp", host: host, logout_challenge: transaction.logout_challenge), headers: {
      "X-TEST-CURRENT-STAFF" => staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :see_other
    assert_equal auth_org_root_url(ri: "jp", host: host), response.location
    assert_predicate token.reload, :currently_usable?
    assert_predicate transaction.reload, :failed?

    delete auth_org_sign_out_url(ri: "jp", host: host, logout_challenge: transaction.logout_challenge), headers: {
      "X-TEST-CURRENT-STAFF" => staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :see_other
    assert_equal auth_org_root_url(ri: "jp", host: host), response.location
    assert_predicate token.reload, :currently_usable?
    assert_predicate transaction.reload, :failed?
  end
end
