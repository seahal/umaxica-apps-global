# typed: false
# frozen_string_literal: true

require "test_helper"

class Side::Com::RootsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("SIDE_CORPORATE_URL")
  end

  test "renders anonymous root" do
    host! @host

    get side_com_root_url(ri: "jp")

    assert_response :success
    assert_select "h1", text: "Side Com"
  end

  test "redirects signed-in visitor to dashboard" do
    host! @host
    visitor = create_verified_visitor_with_email(email_address: "base-com-root-#{SecureRandom.hex(4)}@example.com")
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    satisfy_visitor_verification(token)

    get side_com_root_url(ri: "jp"),
        headers: as_visitor_headers(visitor, host: @host, session_public_id: token.public_id)

    assert_response :redirect
    assert_redirected_to side_com_dashboard_url(ri: "jp", host: @host)
  end
end
