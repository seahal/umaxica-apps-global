# typed: false
# frozen_string_literal: true

require "test_helper"

class Side::Org::RootsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("SIDE_STAFF_URL")
    @operator = operators(:one)
    @token = OperatorToken.create!(staff: @operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    satisfy_staff_verification(@token)
  end

  test "renders anonymous root" do
    host! @host

    get side_org_root_url(ri: "jp")

    assert_response :success
    assert_select "h1", text: "Side Org"
  end

  test "redirects signed-in operator to dashboard" do
    host! @host

    get side_org_root_url(ri: "jp"),
        headers: as_staff_headers(@operator, host: @host, session_public_id: @token.public_id)

    assert_response :redirect
    assert_redirected_to side_org_dashboard_url(ri: "jp", host: @host)
  end
end
