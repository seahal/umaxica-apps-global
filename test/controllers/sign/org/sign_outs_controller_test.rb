# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Sign::OutsControllerTest < ActionDispatch::IntegrationTest
  test "sign org sign-out ceremony routes are retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("ID_STAFF_URL", "id.org.localhost")}/sign/out/confirmation",
        method: :get,
      )
    end
  end

  test "get sign out renders confirmation and post starts RP logout" do
    host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    acme_host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    staff = operators(:one)
    token = OperatorToken.create!(staff: staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    satisfy_staff_verification(token)
    host! host

    get edit_sign_org_sign_out_url(ri: "jp", host: host), headers: {
      "X-TEST-CURRENT-STAFF" => staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :success

    post sign_org_sign_out_url(ri: "jp", host: host), headers: {
      "X-TEST-CURRENT-STAFF" => staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :temporary_redirect
    location = URI.parse(jump_rt_url_from_location(response.location))
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal acme_host, location.host
    assert_equal "/oidc/logout", location.path
    assert_predicate query["id_token_hint"], :present?
    assert_equal complete_sign_org_sign_out_url(ri: "jp", host: host), query["post_logout_redirect_uri"]
    assert_predicate query["state"], :present?
  end
end
