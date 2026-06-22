# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Sign::OutsControllerTest < ActionDispatch::IntegrationTest
  test "sign com sign-out ceremony routes are retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost")}/sign/out/confirmation",
        method: :get,
      )
    end
  end

  test "get sign out renders confirmation and post starts RP logout" do
    host = ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost")
    acme_host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    visitor = create_verified_visitor_with_email(email_address: "sign-com-#{SecureRandom.hex(4)}@example.com")
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    satisfy_visitor_verification(token)
    host! host

    get edit_sign_com_sign_out_url(ri: "jp", host: host), headers: {
      "X-TEST-CURRENT-RESOURCE" => visitor.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :success

    post sign_com_sign_out_url(ri: "jp", host: host), headers: {
      "X-TEST-CURRENT-RESOURCE" => visitor.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :see_other
    location = URI.parse(jump_rt_url_from_location(response.location))
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal acme_host, location.host
    assert_equal "/oidc/logout", location.path
    assert_predicate query["id_token_hint"], :present?
    assert_equal complete_sign_com_sign_out_url(ri: "jp", host: host, protocol: "https"),
                 query["post_logout_redirect_uri"]
    assert_predicate query["state"], :present?
  end
end
